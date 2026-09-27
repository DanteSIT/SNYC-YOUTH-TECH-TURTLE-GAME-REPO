#!/usr/bin/env python3
"""Rebuild the seabed in every level as ONE continuous surface per level.

WHY
---
The floor used to be N independent BoxMesh instances per level, each 13 x 6 x L,
laid end to end along Z with a 0.5 m overlap and each sitting at its own random
top height (GROUND_TOP_CLAMP -1.4..1.8). That produces, every single time:

  * hard step edges where two boxes meet at different heights -- the "broken"
    terrace look;
  * z-fighting where two tops land near-coplanar;
  * a vertical wall of sand at every seam, because the boxes are 6 m tall solids
    and the taller one simply sticks out through the shorter one;
  * N overlapping caustics quads (one per box) double-darkening the floor.

The player also collides with those boxes, so deleting them outright drops the
turtle into the void. The replacement has to keep a floor.

WHAT THIS DOES
--------------
Replaces the N boxes with a single continuous heightfield per level: one quad
strip whose top follows a SMOOTHED version of the same walk, plus one matching
trimesh collider. The relief is preserved (same shape, just smoothed), so the
level design intent survives, but there is now exactly one surface -- no seams,
no steps, no z-fighting, one draw call.

Idempotent: re-running removes the previously generated nodes and re-emits them.
"""

import glob
import math
import os
import re
import sys

LEVELS = sorted(glob.glob("scenes/levels/*.tscn"))

BED_X = -1.5          # matches the old box origin
BED_HALF_W = 6.5      # 13 m wide, same footprint as before
Z_STEP = 1.5          # metres between heightfield samples along the corridor
SKIRT_BOTTOM = -6.0   # matches the old boxes' 6 m depth, so the near edge still
                      # fills the bottom of the frame instead of showing through
SAND = "res://materials/sand.tres"
SAND_ID = "m_sand"

# Godot treats clockwise triangles as front faces, so a surface has to be wound
# such that its right-hand-rule normal points out of the solid: up for the sand
# top, +X for the skirt. A trimesh wound the other way is invisible under
# cull_back and cannot be stood on, and --unflip exists so the orientation can be
# re-tested from a render rather than taken on trust.
REVERSE = True


def quad(idx, a, b, c, d):
    """Two triangles for quad a-b-c-d (a,b on one row; c,d on the next)."""
    if REVERSE:
        idx += [a, c, b, b, c, d]
    else:
        idx += [a, b, c, b, d, c]

# --- patterns ---------------------------------------------------------------
# re.M matters: the pattern is anchored to a line start but is matched against
# the whole file with finditer, so without MULTILINE it only ever matches offset 0
# and every level reports "no seabed boxes".
OLD_BED = re.compile(
    r'^\[node name="Bed\d+" parent="Terrain"[^\]]*instance=ExtResource\("o_seabed"\)\]\n'
    r'transform = Transform3D\([^\n]*\)\n\n?', re.M)

OLD_GEN_SUB = re.compile(
    r'^\[sub_resource type="(?:ArrayMesh|ConcavePolygonShape3D)" id="seabed_(?:mesh|shape)"\][\s\S]*?'
    r'(?=^\[)', re.M)

OLD_GEN_NODES = re.compile(
    r'^\[node name="SeabedBody" type="StaticBody3D" parent="Terrain"\]\n\n'
    r'\[node name="Seabed" type="MeshInstance3D" parent="Terrain/SeabedBody"\][\s\S]*?'
    r'(?=^\[)', re.M)


def read_beds(text):
    """Collect (z, top, z0, z1) for every old seabed box, ordered by z."""
    beds = []
    for m in OLD_BED.finditer(text):
        tm = re.search(r'Transform3D\(([^)]*)\)', m.group(0))
        if not tm:
            continue
        v = [float(x) for x in tm.group(1).split(",")]
        # .tscn Transform3D is 12 floats: basis column-major (9) + origin (3)
        sy, sz = v[4], v[8]
        oy, oz = v[10], v[11]
        beds.append({"z": oz, "top": oy + sy / 2.0,
                     "z0": oz - sz / 2.0, "z1": oz + sz / 2.0})
    beds.sort(key=lambda b: b["z"])
    return beds


def smooth_walk(beds, z_lo, z_hi):
    """Sample the old step function onto a Z_STEP grid, then blur it.

    A box centred at z covers z0..z1, so a sample inside that span takes that
    box's top. Two 5-tap box blurs then turn the staircase into a ramp without
    flattening the overall relief.
    """
    zs, ys = [], []
    z = z_lo
    while z < z_hi - Z_STEP * 0.25:
        top = None
        for b in beds:
            if b["z0"] - 1e-6 <= z <= b["z1"] + 1e-6:
                top = b["top"]
                break
        if top is None:
            top = min(beds, key=lambda b: min(abs(z - b["z0"]), abs(z - b["z1"])))["top"]
        zs.append(z)
        ys.append(top)
        z += Z_STEP
    zs.append(z_hi)
    ys.append(beds[-1]["top"])

    for _ in range(2):
        sm = []
        for i in range(len(ys)):
            lo = max(0, i - 2)
            hi = min(len(ys), i + 3)
            sm.append(sum(ys[lo:hi]) / (hi - lo))
        ys = sm
    return list(zip(zs, ys))


def profile_at(prof, z):
    """Smoothstep-interpolated lookup into the smoothed profile."""
    if z <= prof[0][0]:
        return prof[0][1]
    if z >= prof[-1][0]:
        return prof[-1][1]
    lo, hi = 0, len(prof) - 1
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if prof[mid][0] <= z:
            lo = mid
        else:
            hi = mid
    z0, y0 = prof[lo]
    z1, y1 = prof[hi]
    t = 0.0 if z1 == z0 else (z - z0) / (z1 - z0)
    t = t * t * (3.0 - 2.0 * t)
    return y0 + (y1 - y0) * t


def build_rows(prof, x_half):
    """Build the seabed surface, plus a skirt so the near edge is not see-through.

    The old boxes were 6 m tall solids, so they hid everything below the sand.
    A bare heightfield would leave the bottom of the frame looking through the
    floor's near edge into whatever is behind it, so one continuous skirt is
    hung off the +X (camera-facing) edge all the way down. It is a single wall
    for the whole corridor, so it reintroduces none of the per-seam sand walls
    that made the old seabed look broken.

    Returns (verts, normals, uvs, render_idx, collide_idx). Collision only needs
    the top surface: the player is confined to the x=0 plane, so it can never
    get under the bed, and a trimesh that included the skirt would only give the
    one-sided shapes extra faces to reject from the wrong side.
    """
    n = len(prof)
    eps = 0.05

    # --- top surface: two columns (far, near) per row
    verts, normals, uvs = [], [], []
    for i, (z, y) in enumerate(prof):
        slope = (profile_at(prof, z + eps) - profile_at(prof, z - eps)) / (2 * eps)
        nl = math.hypot(1.0, slope)
        nrm = (0.0, 1.0 / nl, -slope / nl)
        v = i / max(1, n - 1)
        verts.append((BED_X - x_half, y, z))
        normals.append(nrm)
        uvs.append((0.0, v))
        verts.append((BED_X + x_half, y, z))
        normals.append(nrm)
        uvs.append((1.0, v))
    collide, r_idx = [], []
    for i in range(n - 1):
        a = i * 2
        quad(collide, a, a + 1, a + 2, a + 3)
    r_idx += collide

    # --- near-edge skirt: vertical wall from the surface down to SKIRT_BOTTOM
    base = len(verts)
    for i, (z, y) in enumerate(prof):
        v = i / max(1, n - 1)
        verts.append((BED_X + x_half, y, z))
        normals.append((1.0, 0.0, 0.0))
        uvs.append((v, 0.0))
        verts.append((BED_X + x_half, SKIRT_BOTTOM, z))
        normals.append((1.0, 0.0, 0.0))
        uvs.append((v, 1.0))
    for i in range(n - 1):
        a = base + i * 2
        quad(r_idx, a, a + 1, a + 2, a + 3)

    return verts, normals, uvs, r_idx, collide


def flat(vals, nd=4):
    return ", ".join(f"{c:.{nd}f}" for v in vals for c in v)


def build_heightmap(prof, z_lo, z_hi):
    """HeightMapShape3D data covering the same surface as the render mesh.

    HeightMapShape3D has one cell size (1 m) in both axes and centres its grid
    on the node origin, so the grid is built on whole-metre z indices that
    straddle the sampled profile, and the CollisionShape3D is offset to put the
    grid back where the bed actually is. The bed is flat across x, so every cell
    in a row carries that row's height.

    Returns (width, depth, origin, heights) with heights in row-major z order.
    """
    z0 = math.floor(z_lo)
    z1 = math.ceil(z_hi)
    w = int(round(2 * BED_HALF_W)) + 1          # 1 m cells, straddling the bed
    d = int(z1 - z0) + 1
    heights = []
    for j in range(d):
        y = profile_at(prof, z0 + j)
        heights.extend([y] * w)
    # cell (i, j) sits at local (i - (w-1)/2, y, j - (d-1)/2); place the node so
    # that lands the grid on the bed's footprint.
    origin = (BED_X, 0.0, z0 + (d - 1) * 0.5)
    return w, d, origin, heights


def process(path, write=True):
    with open(path) as fh:
        text = fh.read()
    beds = read_beds(text)
    if not beds:
        return None

    z_lo = min(b["z0"] for b in beds)
    z_hi = max(b["z1"] for b in beds)
    prof = smooth_walk(beds, z_lo, z_hi)
    verts, normals, uvs, r_idx, c_idx = build_rows(prof, BED_HALF_W)

    v_flat = flat(verts)
    n_flat = flat(normals)
    uv_flat = flat(uvs)
    r_flat = ", ".join(str(k) for k in r_idx)

    # Collision is a HeightMapShape3D rather than a trimesh of the same surface.
    # The seabed is a heightfield to begin with, so the engine's own heightfield
    # collider is the natural fit, and it sidesteps ConcavePolygonShape3D's flat
    # `data` array, whose layout is undocumented enough that several plausible
    # encodings all parse without error and quietly produce a shape with no
    # collision at all.
    hm_w, hm_d, hm_origin, hm_data = build_heightmap(prof, z_lo, z_hi)
    hm_flat = ", ".join(f"{h:.4f}" for h in hm_data)

    # 1. strip previously generated nodes + sub_resources (idempotency)
    text = OLD_GEN_NODES.sub("", text)
    text = OLD_GEN_SUB.sub("", text)

    # 2. the old seabed instance carried the sand material on its own BoxMesh.
    #    This is a bare MeshInstance3D with its own mesh, so it needs the
    #    material referred to from here instead.
    if f'id="{SAND_ID}"' not in text:
        last = None
        for m in re.finditer(r'^\[ext_resource [^\n]*\]\n', text, re.M):
            last = m
        line = f'[ext_resource type="Material" path="{SAND}" id="{SAND_ID}"]\n'
        text = text[:last.end()] + line + text[last.end():]
        # load_steps is only a preallocation hint and is already inconsistent in
        # some of these scenes, but keep it honest where it is present.
        text = re.sub(r'^(\[gd_scene load_steps=)(\d+)( format=3\])',
                      lambda m: m.group(1) + str(int(m.group(2)) + 3) + m.group(3),
                      text, count=1, flags=re.M)

    # 3. emit the mesh + collider sub_resources before the first [node
    subs = (
        '[sub_resource type="ArrayMesh" id="seabed_mesh"]\n'
        f'_data = {{"vertex_data": PackedVector3Array({v_flat}), '
        f'"normal_data": PackedVector3Array({n_flat}), '
        f'"uv_data": PackedVector2Array({uv_flat}), '
        f'"index_data": PackedInt32Array({r_flat})}}\n\n'
        '[sub_resource type="HeightMapShape3D" id="seabed_shape"]\n'
        f'map_width = {hm_w}\n'
        f'map_depth = {hm_d}\n'
        f'map_data = PackedFloat32Array({hm_flat})\n\n'
    )
    m = re.search(r'^\[node ', text, re.M)
    text = text[:m.start()] + subs + text[m.start():]

    # 4. swap the old per-segment boxes for the new ones. The replacement reuses
    #    the slot the first box occupied: most levels declare Terrain as an empty
    #    node and list its children further down the file, so "insert just after
    #    the Terrain header" has nowhere reliable to go.
    nodes = (
        '[node name="SeabedBody" type="StaticBody3D" parent="Terrain"]\n\n'
        '[node name="Seabed" type="MeshInstance3D" parent="Terrain/SeabedBody"]\n'
        'mesh = SubResource("seabed_mesh")\n'
        f'material_override = ExtResource("{SAND_ID}")\n'
        'cast_shadow = 0\n\n'
        '[node name="Col" type="CollisionShape3D" parent="Terrain/SeabedBody"]\n'
        f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {hm_origin[0]:.4f}, '
        f'{hm_origin[1]:.4f}, {hm_origin[2]:.4f})\n'
        'shape = SubResource("seabed_shape")\n\n'
    )
    placed = []

    def swap(m):
        if placed:
            return ""
        placed.append(True)
        return nodes

    text = OLD_BED.sub(swap, text)
    if not placed:                                   # defensive; needs beds to run
        m2 = re.search(r'^\[node name="Terrain"[^\]]*\]\n', text, re.M)
        text = text[:m2.end()] + "\n" + nodes + text[m2.end():]

    if write:
        with open(path, "w") as fh:
            fh.write(text)

    old_ys = [b["top"] for b in beds]
    new_ys = [y for _, y in prof]
    return {
        "name": os.path.basename(path), "n": len(beds), "z_lo": z_lo, "z_hi": z_hi,
        "old": (min(old_ys), max(old_ys)), "new": (min(new_ys), max(new_ys)),
        "rows": len(prof), "tris": len(r_idx) // 3, "ctris": len(c_idx) // 3,
    }


def main():
    global REVERSE, LEVELS
    if "--unflip" in sys.argv:
        REVERSE = False
    only = None
    if "--only" in sys.argv:
        only = sys.argv[sys.argv.index("--only") + 1]
        # exact stem match: a substring test would pull in level_10..15 for
        # --only level_1
        LEVELS = [p for p in LEVELS
                  if os.path.splitext(os.path.basename(p))[0] == only]
        if not LEVELS:
            print(f"no level matches --only {only}")
            return
    write = "--dry" not in sys.argv
    total = 0
    print(f"{'level':16s} {'boxes':>5s} -> {'rows':>4s} tris   z range          "
          f"top before -> after{'   (UNFLIPPED winding)' if not REVERSE else ''}")
    for path in LEVELS:
        r = process(path, write=write)
        if r is None:
            print(f"{os.path.basename(path):16s} no seabed boxes, skipped")
            continue
        total += r["n"]
        print(f"{r['name']:16s} {r['n']:5d} -> {r['rows']:4d} {r['tris']:4d}   "
              f"{r['z_lo']:7.1f}..{r['z_hi']:7.1f}   "
              f"{r['old'][0]:5.2f}..{r['old'][1]:5.2f} -> "
              f"{r['new'][0]:5.2f}..{r['new'][1]:5.2f}")
    print(f"\n{total} interpenetrating sand boxes -> 16 continuous surfaces"
          f"{'  (DRY RUN, nothing written)' if not write else ''}")


if __name__ == "__main__":
    main()
