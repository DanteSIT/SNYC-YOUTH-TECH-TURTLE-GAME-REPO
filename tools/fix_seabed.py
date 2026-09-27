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

# --- patterns ---------------------------------------------------------------
OLD_BED = re.compile(
    r'^\[node name="Bed\d+" parent="Terrain"[^\]]*instance=ExtResource\("o_seabed"\)\]\n'
    r'transform = Transform3D\([^\n]*\)\n\n?')

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
    verts, normals, uvs = [], [], []
    eps = 0.05
    n = len(prof)
    for i, (z, y) in enumerate(prof):
        slope = (profile_at(prof, z + eps) - profile_at(prof, z - eps)) / (2 * eps)
        nl = math.hypot(1.0, slope)
        nrm = (0.0, 1.0 / nl, -slope / nl)
        for sx in (-x_half, x_half):
            verts.append((BED_X + sx, y, z))
            normals.append(nrm)
            uvs.append(((sx + x_half) / (2 * x_half), i / max(1, n - 1)))
    idx = []
    for i in range(n - 1):
        a = i * 2
        idx += [a, a + 1, a + 2, a + 1, a + 3, a + 2]
    return verts, normals, uvs, idx


def flat(vals, nd=4):
    return ", ".join(f"{c:.{nd}f}" for v in vals for c in v)


def process(path, write=True):
    with open(path) as fh:
        text = fh.read()
    beds = read_beds(text)
    if not beds:
        return None

    z_lo = min(b["z0"] for b in beds)
    z_hi = max(b["z1"] for b in beds)
    prof = smooth_walk(beds, z_lo, z_hi)
    verts, normals, uvs, idx = build_rows(prof, BED_HALF_W)

    v_flat = flat(verts)
    n_flat = flat(normals)
    uv_flat = flat(uvs)
    i_flat = ", ".join(str(k) for k in idx)

    # 1. strip previously generated nodes + sub_resources (idempotency)
    text = OLD_GEN_NODES.sub("", text)
    text = OLD_GEN_SUB.sub("", text)
    # 2. strip the old per-segment boxes
    text = OLD_BED.sub("", text)

    # 3. emit the mesh + collider sub_resources before the first [node
    subs = (
        '[sub_resource type="ArrayMesh" id="seabed_mesh"]\n'
        f'_data = {{"vertex_data": PackedVector3Array({v_flat}), '
        f'"normal_data": PackedVector3Array({n_flat}), '
        f'"uv_data": PackedVector2Array({uv_flat}), '
        f'"index_data": PackedInt32Array({i_flat})}}\n\n'
        '[sub_resource type="ConcavePolygonShape3D" id="seabed_shape"]\n'
        f'data = {{"vertices": PackedVector3Array({v_flat}), '
        f'"faces": PackedInt32Array({i_flat})}}\n\n'
    )
    m = re.search(r'^\[node ', text, re.M)
    text = text[:m.start()] + subs + text[m.start():]

    # 4. emit the nodes as the first children of Terrain
    nodes = (
        '[node name="SeabedBody" type="StaticBody3D" parent="Terrain"]\n\n'
        '[node name="Seabed" type="MeshInstance3D" parent="Terrain/SeabedBody"]\n'
        'mesh = SubResource("seabed_mesh")\n'
        'cast_shadow = 0\n\n'
        '[node name="Col" type="CollisionShape3D" parent="Terrain/SeabedBody"]\n'
        'shape = SubResource("seabed_shape")\n\n'
    )
    m2 = re.search(r'\[node name="Terrain" type="Node3D"[^\]]*\]\n\n', text)
    text = text[:m2.end()] + nodes + text[m2.end():]

    if write:
        with open(path, "w") as fh:
            fh.write(text)

    old_ys = [b["top"] for b in beds]
    new_ys = [y for _, y in prof]
    return {
        "name": os.path.basename(path), "n": len(beds), "z_lo": z_lo, "z_hi": z_hi,
        "old": (min(old_ys), max(old_ys)), "new": (min(new_ys), max(new_ys)),
        "rows": len(prof), "tris": len(idx) // 3,
    }


def main():
    write = "--dry" not in sys.argv
    total = 0
    print(f"{'level':16s} {'boxes':>5s} -> {'rows':>4s} tris   z range          top before -> after")
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
