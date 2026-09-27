#!/usr/bin/env python3
"""
clean_levels.py — clean up the post-relength level scenes to match level_1.

After relength.py shrank the pipe spans (80/110/140 tiers), every level except
the reference (level_1) was left with authored content dangling beyond the
sealed pipe mouths: unreachable gameplay objects (collectables/gates/hazards/
platforms) and far-out scenery (fish, coral, rocks, roof tiles, seabed).

This pass makes the other levels look like level_1:

  1. RELOCATE — gameplay objects beyond the pipes are pulled back into the
     corridor instead of deleted (difficulty/collectable economy preserved).
     Per category, the beyond-pipe items are re-placed into free z-slots of the
     corridor, preserving their authored order and their x/y offset, walking
     inward from each pipe so the end-side items land near the goal and the
     start-side items land near spawn.  Keep-out pads keep the pipe mouths,
     the spawn anchor and the goal clear; per-category spacing prevents
     overlaps between relocated items and everything already inside.

  2. TRIM — scenery whose inner edge sits more than APRON metres (default 6,
     matching level_1's own footprint) past a pipe is deleted.  Beds and other
     large-spanning tiles are handled by the same inner-edge rule, so the floor
     never gets a hole inside the corridor or its end apron.

The sealed pipe mouths (StaticBody3D + concave cap on transition_pipe.tscn)
mean nothing past a pipe is ever reachable, so removal/relocation is lossless
for gameplay.  level_1 is skipped — it is the reference for what a cleaned
level should look like.

Idempotent: re-running is a no-op.  Only the target transform z components are
rewritten (no reordering, no unique_id churn) and whole node blocks are deleted
for the trim — same rules as relength.py / theme_levels.py.

Usage:
    python3 tools/pipeline/clean_levels.py            # apply
    python3 tools/pipeline/clean_levels.py --dry-run  # preview only
    CLEAN_APRON=4 python3 tools/pipeline/clean_levels.py  # tighter trim margin
"""
import bisect
import os
import re
import sys

ROOT = os.environ.get(
    "CLEAN_ROOT",
    os.path.normpath(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scenes", "levels")
    ),
)
APRON = float(os.environ.get("CLEAN_APRON", "6.0"))

LEVELS = ["tutorial.tscn"] + ["level_%d.tscn" % i for i in range(1, 16)]
REFERENCE = {"level_1.tscn"}  # untouched — the model every other level matches

# Per-category placement tuning: r = half-extent kept clear around any node,
# end_pad = keep-out distance from the goal pipe, start_pad = keep-out from
# the start pipe (spawn).  Processed in order: biggest items first so small
# collectables weave around them later.
# exclude: scenery-less bands used to block a category.  The big items
# (Gate/Hazard/Platform) must not be crowded out by dense collectable lines,
# so collectables never reserve z-room against them.  Collect itself weaves
# around every functional node, hence the empty exclusion set.
CATS = [
    {"key": "Gate", "r": 2.2, "end_pad": 8.0, "start_pad": 6.0, "exclude": {"collectable"}},
    {"key": "Hazard", "r": 1.3, "end_pad": 4.0, "start_pad": 4.0, "exclude": {"collectable"}},
    {"key": "Platform", "r": 1.8, "end_pad": 5.0, "start_pad": 5.0, "exclude": {"collectable"}},
    {"key": "Collect", "r": 0.8, "end_pad": 2.0, "start_pad": 1.5, "exclude": frozenset()},
]

NODE_RE = re.compile(r'^\[node name="([^"]+)"')
TRANS_RE = re.compile(r"^(.*?)transform = Transform3D\((.*)\)\s*$")
GADGET_RE = re.compile(r"^(Collect|Gate|Hazard|Platform)\d+$")


def fnum(v):
    """Shortest decimal repr in the style Godot writes to .tscn files."""
    s = "%.3f" % v
    s = s.rstrip("0").rstrip(".")
    if s in ("", "-0"):
        s = "0"
    return s


def fmt_transform(prefix, args):
    core = ", ".join(a.strip() for a in args)
    return "%stransform = Transform3D(%s)" % (prefix, core)


def node_blocks(lines):
    """(start, end) index pairs for every '['-delimited block in the file."""
    starts = [i for i, l in enumerate(lines) if l.startswith("[")]
    blocks = []
    for k, s in enumerate(starts):
        e = starts[k + 1] if k + 1 < len(starts) else len(lines)
        blocks.append((s, e))
    return blocks


def block_name(lines, s):
    m = NODE_RE.match(lines[s])
    return m.group(1) if m else None


def block_transform(lines, s, e):
    """Return (line_idx, prefix, args) of the block's transform, or None."""
    for j in range(s, e):
        m = TRANS_RE.match(lines[j])
        if m:
            return j, m.group(1), [a.strip() for a in m.group(2).split(",")]
    return None


def find_pipes(lines, blocks):
    lo = hi = None
    for s, e in blocks:
        name = block_name(lines, s)
        if name in ("StartPipe", "EndPipe"):
            t = block_transform(lines, s, e)
            if t and len(t[2]) >= 12:
                z = float(t[2][11])
                if name == "StartPipe":
                    hi = z
                else:
                    lo = z
    return lo, hi


def is_beyond(lines, s, e, lo, hi):
    """True when an *instanced* node's inner edge sits past pipe + APRON."""
    if "instance=" not in lines[s]:
        return False
    name = block_name(lines, s)
    if name is None or GADGET_RE.match(name):
        return False  # gameplay objects are handled by relocation
    if scene_base(lines, lines[s]) == "ocean_particles":
        return False  # debris pockets are repositioned by place_debris.py
    t = block_transform(lines, s, e)
    if t is None or len(t[2]) < 12:
        return False
    z = float(t[2][11])
    half = abs(float(t[2][8])) / 2.0
    if z >= hi:
        return z - half > hi + APRON
    if z <= lo:
        return z + half < lo - APRON
    return False


STRUCT_SCENES = {
    "transition_pipe", "goal", "turtle", "chaser", "boss", "current",
}
FUNC_SCENES = STRUCT_SCENES | {"obstacle", "hazard", "platform", "collectable"}


def ext_paths(lines):
    """Map ext_resource id -> scene path (basename)."""
    out = {}
    for l in lines:
        m = re.match(r'\[ext_resource type="PackedScene"[^]]*path="([^"]+)" id="([^"]+)"', l)
        if m:
            out[m.group(2)] = m.group(1)
    return out


def scene_base(lines, header):
    m = re.search(r'instance=ExtResource\("([^"]+)"\)', header)
    if not m:
        return None
    path = _EXTS.get(m.group(1))
    return os.path.basename(path) if path else None


def fixed_bands(lines, blocks, lo, hi, r, exclude_scenes=frozenset()):
    """Sorted forbidden z-bands around in-corridor *functional* nodes.

    Scenery (beds, rocks, plants, fish...) is deliberately NOT forbidden — it is
    cosmetic at other x/y offsets and would leave no placement room.  Only
    gameplay/structural nodes reserve z-room.
    """
    bands = []
    for s, e in blocks:
        name = block_name(lines, s)
        if name is None or "instance=" not in lines[s]:
            continue
        base = scene_base(lines, lines[s])
        if base is None or base not in FUNC_SCENES or base in exclude_scenes:
            continue
        t = block_transform(lines, s, e)
        if t is None or len(t[2]) < 12:
            continue
        z = float(t[2][11])
        if z <= lo or z >= hi:
            continue
        bands.append((z - r, z + r))
    bands.sort()
    return bands


_EXTS = {}


def insert_band(bands, a, b):
    bisect.insort(bands, (a, b))
    return bands


def first_free(z0, direction, bands, r, lo, hi):
    """First z >=/< z0 (walking by `direction`) clear of every band."""
    z = z0
    while lo - 0.05 <= z <= hi + 0.05:
        region = (z - r, z + r)
        ok = True
        for a, b in bands:
            if b <= region[0]:
                continue
            if a >= region[1]:
                break
            ok = False
            break
        if ok:
            return z
        z += direction * 0.05
    return None


def relocate_category(lines, blocks, cat, lo, hi):
    """Pull gadgets past the pipes back into the corridor. Returns placements."""
    prefix = cat["key"]
    r, ep, sp = cat["r"], cat["end_pad"], cat["start_pad"]
    exclude = cat.get("exclude", frozenset())
    items = []
    for s, e in blocks:
        name = block_name(lines, s)
        if name is None or not re.fullmatch(prefix + r"\d+", name):
            continue
        t = block_transform(lines, s, e)
        if t is None or len(t[2]) < 12:
            continue
        z = float(t[2][11])
        if z > hi or z < lo:
            items.append((name, z, t))
    if not items:
        return []

    fwd = sorted((it for it in items if it[1] < lo), key=lambda it: it[1])
    bwd = sorted((it for it in items if it[1] > hi), key=lambda it: -it[1])

    bands = fixed_bands(lines, blocks, lo, hi, r, exclude_scenes=exclude)
    insert_band(bands, hi - sp, hi + 1.0)   # keep-out: start pipe / spawn
    insert_band(bands, lo - 1.0, lo + ep)   # keep-out: goal pipe
    placed = []

    def walk(group, start, direction):
        nonlocal bands
        cursor = start
        for name, z_old, t in group:
            z_new = first_free(cursor, direction, bands, r, lo, hi)
            if z_new is None:
                raise RuntimeError(
                    "no free slot for %s %s (was z=%.1f)" % (prefix, name, z_old))
            placed.append((name, z_new, t))
            insert_band(bands, z_new - r, z_new + r)
            cursor = z_new + direction * (2.0 * r + 0.25)

    if fwd:
        walk(fwd, lo + ep, +1.0)
    if bwd:
        walk(bwd, hi - sp, -1.0)
    return placed


def apply_relocations(lines, placed):
    for name, z_new, (idx, prefix, args) in placed:
        args[11] = fnum(z_new)
        lines[idx] = fmt_transform(prefix, args)


def trim_scenery(lines, lo, hi):
    """Delete scenery node blocks whose inner edge is past pipe + APRON."""
    blocks = node_blocks(lines)
    drop = [(s, e) for s, e in blocks if is_beyond(lines, s, e, lo, hi)]
    for s, e in reversed(drop):
        end = e
        if end < len(lines) and lines[end] == "":
            end += 1  # swallow the blank separator line too
        del lines[s:end]
    return len(drop)


def main():
    global _EXTS
    dry = "--dry-run" in sys.argv
    changed = 0
    for name in LEVELS:
        path = os.path.join(ROOT, name)
        if not os.path.exists(path):
            print("SKIP %s (missing)" % name)
            continue
        with open(path, "r", encoding="utf-8") as f:
            orig = f.read()
        lines = orig.split("\n")
        _EXTS = ext_paths(lines)  # needed by scene_base() during relocate/trim
        blocks = node_blocks(lines)
        lo, hi = find_pipes(lines, blocks)
        if lo is None or hi is None:
            print("SKIP %s (no pipe transforms)" % name)
            continue

        if name in REFERENCE:
            print("SKIP %s (reference level, untouched)" % name)
            continue

        summary = []
        try:
            for cat in CATS:
                placed = relocate_category(lines, blocks, cat, lo, hi)
                apply_relocations(lines, placed)
                if placed:
                    summary.append("%s:%d" % (cat["key"], len(placed)))
        except RuntimeError as exc:
            print("FAIL %s: %s" % (name, exc))
            return 1

        blocks = node_blocks(lines)  # line count unchanged by relocate, but re-scan anyway
        trimmed = trim_scenery(lines, lo, hi)
        if trimmed:
            summary.append("trim:%d" % trimmed)

        text = "\n".join(lines)
        if text == orig:
            print("NOCHANGE %s" % name)
            continue
        if dry:
            print("DRY %s: %s" % (name, ", ".join(summary) if summary else "no-op?"))
        else:
            with open(path, "w", encoding="utf-8") as f:
                f.write(text)
            print("CLEAN %s: %s" % (name, ", ".join(summary)))
            changed += 1
    print("done, %d level(s) updated" % changed)
    return 0


if __name__ == "__main__":
    sys.exit(main() or 0)