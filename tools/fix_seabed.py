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

# Commit to read the original bed box transforms from, set by --beds-from. Once
# a level has been converted the boxes are gone from the working tree, so a
# re-run has nothing to reconstruct the profile from unless it is told where.
BEDS_REF = None


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
    # HeightMapShape3D has to be in here too. The collider was a
    # ConcavePolygonShape3D first and is a HeightMapShape3D now, and a regex
    # listing only the old type silently stops matching -- so re-running the tool
    # leaves the previous collider in place and appends another one, and the
    # scene quietly grows a fresh duplicate on every invocation.
    r'^\[sub_resource type="(?:ArrayMesh|ConcavePolygonShape3D|HeightMapShape3D)"'
    r' id="seabed_(?:mesh|shape)"\][\s\S]*?'
    r'(?=^\[)', re.M)

OLD_GEN_NODES = re.compile(
    r'^\[node name="SeabedBody" type="StaticBody3D" parent="Terrain"\]\n\n'
    r'\[node name="Seabed" type="MeshInstance3D" parent="Terrain/SeabedBody"\][\s\S]*?'
    r'(?=^\[node name="Col" type="CollisionShape3D" parent="Terrain/SeabedBody"\])'
    # The collider has to be consumed as well. The lazy match above stops at the
    # Col header, so without this the old Col survives while a fresh one is
    # emitted below it, and every re-run appends another copy.
    r'\[node name="Col" type="CollisionShape3D" parent="Terrain/SeabedBody"\][\s\S]*?'
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
    """Flatten nested per-vertex tuples into a plain list of floats.

    This is what goes into the JSON dump read by tools/mesh_from_arrays.gd, so it
    has to be a real list. An earlier version returned a pre-joined ", ".join()
    string for direct splicing into the .tscn; that arrives in GDScript as a
    String, and assigning a String where a PackedVector3Array is expected yields
    an empty vertex array with no error of its own.
    """
    out = []
    for v in vals:
        out.extend(round(float(c), nd) for c in v)
    return out


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


def git_show(ref_path):
    import subprocess
    proc = subprocess.run(["git", "show", ref_path], capture_output=True, text=True)
    if proc.returncode != 0:
        raise SystemExit(f"git show {ref_path} failed: {proc.stderr.strip()}")
    return proc.stdout


def existing_vertex_count(text):
    """Vertex count of a previously emitted seabed_mesh, or None.

    Only understands the old, broken `_data` layout. Its arrays are still a
    faithful record of the geometry that was computed, which makes it a usable
    cross-check: if the profile is being re-read from a different source (a git
    ref, say) the regenerated mesh must still come out the same size.
    """
    m = re.search(r'id="seabed_mesh"\][\s\S]*?"vertex_data": PackedVector3Array\(([^)]*)\)',
                  text)
    if not m or not m.group(1).strip():
        return None
    return m.group(1).count(",") // 3 + 1


def process(path, write=True, surfaces_text=None):
    with open(path) as fh:
        text = fh.read()
    # The bed boxes are consumed by the first run, so re-running against a tree
    # that has already been converted finds nothing to read. --beds-from points
    # the geometry at the pre-conversion commit instead, while the surgery below
    # still applies to the working file.
    beds = read_beds(git_show(BEDS_REF + ":" + path) if BEDS_REF else text)
    if not beds:
        return None

    z_lo = min(b["z0"] for b in beds)
    z_hi = max(b["z1"] for b in beds)
    prof = smooth_walk(beds, z_lo, z_hi)
    verts, normals, uvs, r_idx, c_idx = build_rows(prof, BED_HALF_W)
    stem = os.path.splitext(os.path.basename(path))[0]
    geo = {"vertex": flat(verts), "normal": flat(normals), "uv": flat(uvs),
           "index": r_idx}

    was = existing_vertex_count(text)
    if was is not None and was != len(verts):
        raise SystemExit(
            f"{stem}: regenerated mesh has {len(verts)} vertices but the scene "
            f"already holds a {was}-vertex seabed; the bed profile source and the "
            f"scene have diverged, refusing to overwrite")

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
    #
    # The ArrayMesh body is NOT written here. ArrayMesh serialises as a
    # `_surfaces` array of dictionaries holding interleaved PackedByteArray
    # attribute buffers, a `format` bitmask and a `primitive` enum, and that
    # layout is undocumented: the plausible-looking `_data` form with
    # PackedVector3Arrays parses with no error and no warning, and yields a mesh
    # whose surface_count is 0. Such a mesh draws nothing at all while the scene
    # still loads and still collides, because collision is a separate
    # CollisionShape3D -- so the whole seabed can disappear while every load
    # check and every floor probe still passes. The body therefore comes from
    # tools/mesh_from_arrays.gd, which builds the surface through the documented
    # API and lets ResourceSaver write the file.
    if surfaces_text is None:
        raise SystemExit(f"no generated mesh text for {path}; run via main()")
    subs = (
        '[sub_resource type="ArrayMesh" id="seabed_mesh"]\n'
        f'{surfaces_text}\n'
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

    # The emitted block ends with a blank line and removing the old Bed nodes
    # leaves another one behind it, so without this a stack of blank lines grows
    # by one on every run -- which makes the tool look non-idempotent even though
    # the output is correct. Only this seam is squeezed: engine-written scenes
    # do legitimately contain runs of blank lines elsewhere, so collapsing them
    # globally would churn files this tool has no business touching.
    text = re.sub(r'(shape = SubResource\("seabed_shape"\)\n)\n{2,}', r"\1\n", text)

    if write:
        with open(path, "w") as fh:
            fh.write(text)

    old_ys = [b["top"] for b in beds]
    new_ys = [y for _, y in prof]
    return {
        "name": os.path.basename(path), "n": len(beds), "z_lo": z_lo, "z_hi": z_hi,
        "old": (min(old_ys), max(old_ys)), "new": (min(new_ys), max(new_ys)),
        "rows": len(prof), "tris": len(r_idx) // 3, "ctris": len(c_idx) // 3,
        "stem": stem, "geo": geo, "verts": len(verts), "indices": len(r_idx),
    }


GODOT = "/home/dante-pc/Godot/Engine/Godot_v4.7.2-stable_linux.x86_64"
TMP_OUT = "res://.tmp_seabed"
DUMP = os.path.join("tools", ".seabed_dump.json")


def build_meshes(reports):
    """Have Godot turn each level's surface arrays into a serialised ArrayMesh.

    Returns {stem: sub_resource body}. Raises SystemExit if the engine cannot be
    run, or hands back a mesh with no surfaces -- the silent-invisibility case
    this whole indirection exists to prevent.
    """
    import json
    import shutil
    import subprocess
    import tempfile

    if not os.path.exists(GODOT):
        raise SystemExit(f"Godot binary not found at {GODOT}")
    with open(DUMP, "w") as fh:
        json.dump({"levels": {r["stem"]: r["geo"] for r in reports}}, fh)
    try:
        proc = subprocess.run(
            [GODOT, "--headless", "--path", ".", "--script",
             "res://tools/mesh_from_arrays.gd", "--", DUMP],
            capture_output=True, text=True, timeout=600)
    finally:
        if os.path.exists(DUMP):
            os.remove(DUMP)
    if proc.returncode != 0:
        print(proc.stdout[-3000:])
        print(proc.stderr[-3000:], file=sys.stderr)
        raise SystemExit("mesh_from_arrays.gd failed")
    for line in proc.stdout.splitlines():
        if line.startswith("MESHOK"):
            print(f"  {line}")

    out = {}
    for r in reports:
        path = os.path.join(".tmp_seabed", r["stem"] + ".tres")
        if not os.path.exists(path):
            raise SystemExit(f"engine wrote no mesh for {r['stem']}")
        with open(path) as fh:
            text = fh.read()
        if "_surfaces" not in text:
            raise SystemExit(f"{r['stem']}: serialised mesh has no _surfaces")
        body = text.split("[resource]", 1)[1].strip("\n")
        out[r["stem"]] = body
    shutil.rmtree(".tmp_seabed", ignore_errors=True)
    return out


def main():
    global REVERSE, LEVELS, BEDS_REF
    if "--unflip" in sys.argv:
        REVERSE = False
    BEDS_REF = None
    if "--beds-from" in sys.argv:
        BEDS_REF = sys.argv[sys.argv.index("--beds-from") + 1]
        print(f"reading bed transforms from {BEDS_REF} (working tree is already "
              f"converted; scenes will only have the seabed re-emitted)\n")
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

    # Pass 1: compute the geometry for every level, writing nothing. Pass 2 has
    # to build the meshes for all of them in a single Godot run, so the geometry
    # is gathered before any scene file is touched.
    reports = []
    for path in LEVELS:
        r = process(path, write=False, surfaces_text="")
        if r is None:
            print(f"{os.path.basename(path):16s} no seabed boxes, skipped")
            continue
        reports.append(r)
        total += r["n"]
        print(f"{r['name']:16s} {r['n']:5d} -> {r['rows']:4d} {r['tris']:4d}   "
              f"{r['z_lo']:7.1f}..{r['z_hi']:7.1f}   "
              f"{r['old'][0]:5.2f}..{r['old'][1]:5.2f} -> "
              f"{r['new'][0]:5.2f}..{r['new'][1]:5.2f}")

    if write and reports:
        print("\nbuilding meshes via tools/mesh_from_arrays.gd ...")
        meshes = build_meshes(reports)
        # Pass 2: only now rewrite the scenes.
        for r, path in zip(reports, [p for p in LEVELS
                                     if os.path.splitext(os.path.basename(p))[0]
                                     in meshes]):
            process(path, write=True, surfaces_text=meshes[r["stem"]])

    print(f"\n{total} interpenetrating sand boxes -> {len(reports)} continuous surfaces"
          f"{'  (DRY RUN, nothing written)' if not write else ''}")


if __name__ == "__main__":
    main()
