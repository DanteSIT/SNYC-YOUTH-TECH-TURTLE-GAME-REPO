#!/usr/bin/env python3
"""Flatten the seabed around each level's start and end pipe.

The corridor can be re-lengthed after the terrain is built, which leaves some
pipes buried in sand. This blends the bed top toward FLAT_TOP near each pipe so
the turtle always starts and finishes in open water. Idempotent.
"""

import glob
import os
import re
import sys

LEVELS = sorted(glob.glob("scenes/levels/*.tscn"))

FLAT_TOP = 0.0        # the height the generator itself uses for a fair start
BED = re.compile(
    r'^(\[node name="(Bed\d+)" parent="Terrain"[^\]]*instance=ExtResource\("o_seabed"\)\]\n)'
    r'transform = Transform3D\(([^)]*)\)\n', re.M)
NODE = re.compile(r'^\[node name="(StartPipe|EndPipe)" parent="[^"]*"[^]]*\]')
XF = re.compile(r'^transform = Transform3D\(([^)]*)\)')

# protected window per pipe: (z_from, z_to) in metres, then the taper length
START_WIN = (-12.0, 6.0)     # pipe .. 12 m of run-in ahead of it
END_WIN = (-6.0, 12.0)       # 6 m of approach before the goal, 12 m behind
TAPER = 10.0


def fmt(vals):
    return ", ".join(f"{v:g}" for v in vals)


def weight(z, lo, hi):
    """1.0 inside [lo, hi], ramping linearly to 0.0 over TAPER outside."""
    if lo <= z <= hi:
        return 1.0
    if z < lo:
        d = (lo - z) / TAPER
    else:
        d = (z - hi) / TAPER
    return max(0.0, 1.0 - d)


def blend(top, z, wins):
    w = max(weight(z, lo, hi) for lo, hi in wins) if wins else 0.0
    if w <= 0.0:
        return top, 0.0
    return top + (FLAT_TOP - top) * w, w


def main():
    dry = "--dry" in sys.argv
    print(f"{'level':10s} {'start pipe':>10s} {'end pipe':>9s}  "
          f"{'beds moved':>10s} {'max drop':>9s}  start bed top -> after")
    total = 0
    for path in LEVELS:
        name = os.path.basename(path)[:-5]
        text = open(path).read()

        pipes = {}
        cur = None
        for line in text.splitlines(keepends=True):
            m = NODE.match(line)
            if m:
                cur = m.group(1)
                continue
            m = XF.match(line)
            if m and cur:
                pipes[cur] = float(m.group(1).split(",")[11])
                cur = None
        if "StartPipe" not in pipes:
            print(f"{name:10s} no StartPipe -- skipped")
            continue

        sw = (pipes["StartPipe"] + START_WIN[0], pipes["StartPipe"] + START_WIN[1])
        ew = None
        if "EndPipe" in pipes:
            ew = (pipes["EndPipe"] + END_WIN[0], pipes["EndPipe"] + END_WIN[1])
        wins = [w for w in (sw, ew) if w]

        moved = 0
        maxdrop = 0.0
        start_before = start_after = None

        def repl(m):
            nonlocal moved, maxdrop, start_before, start_after
            vals = [float(x) for x in m.group(3).split(",")]
            sy, oy, oz = vals[4], vals[10], vals[11]
            top = oy + sy / 2.0
            new_top, w = blend(top, oz, wins)
            if abs(new_top - top) < 1e-6:
                return m.group(0)
            moved += 1
            maxdrop = max(maxdrop, top - new_top)
            vals[10] = new_top - sy / 2.0
            if abs(oz - pipes["StartPipe"]) < 4.0:
                start_before = top
                start_after = new_top
            return m.group(1) + "transform = Transform3D(%s)\n" % fmt(vals)

        new_text = BED.sub(repl, text)
        if not dry and new_text != text:
            with open(path, "w") as fh:
                fh.write(new_text)
        total += moved
        sb = f"{start_before:.2f} -> {start_after:.2f}" if start_before is not None else "-"
        print(f"{name:10s} {pipes['StartPipe']:10.2f} "
              f"{pipes.get('EndPipe', float('nan')):9.2f}  {moved:10d} "
              f"{maxdrop:9.2f}  {sb}")

    print(f"\n{total} bed(s) lowered{'  (DRY RUN, nothing written)' if dry else ''}")
    print("start and end now open into flat water instead of a sand bank")


if __name__ == "__main__":
    main()
