#!/usr/bin/env python3
"""Move each level's turtle onto the start pipe axis.

The old spawn sat 2.6 m behind the pipe, inside the tube. Only z is changed, so
the rest of the level stays put. Idempotent.
"""

import glob
import os
import re
import sys

LEVELS = sorted(glob.glob("scenes/levels/*.tscn"))

NODE = re.compile(r'^\[node name="([^"]+)" parent="[^"]*"[^]]*\]')
XF = re.compile(r'^transform = Transform3D\(([^)]*)\)')


def find(path, name):
    """Return (line_index_of_transform, [12 floats]) for a top-level node."""
    lines = open(path).readlines()
    cur = None
    for i, line in enumerate(lines):
        m = NODE.match(line)
        if m:
            cur = m.group(1)
            continue
        m = XF.match(line)
        if m and cur == name:
            return lines, i, [float(x) for x in m.group(1).split(",")]
    return lines, None, None


def fmt(vals):
    out = []
    for v in vals:
        s = f"{v:g}"
        out.append(s)
    return ", ".join(out)


def main():
    dry = "--dry" in sys.argv
    print(f"{'level':10s} {'pipe z':>8s} {'turtle z before':>15s} {'after':>8s} {'move':>7s}")
    changed = 0
    for path in LEVELS:
        name = os.path.basename(path)[:-5]
        lines, ti, tv = find(path, "Turtle")
        _, pi, pv = find(path, "StartPipe")
        if ti is None or pi is None:
            print(f"{name:10s} MISSING Turtle/StartPipe -- skipped")
            continue
        pipe_z = pv[11]
        old_z = tv[11]
        if abs(old_z - pipe_z) < 1e-4:
            print(f"{name:10s} {pipe_z:8.2f} {old_z:15.2f} {old_z:8.2f} {'ok':>7s}")
            continue
        tv[11] = pipe_z
        lines[ti] = "transform = Transform3D(%s)\n" % fmt(tv)
        if not dry:
            with open(path, "w") as fh:
                fh.writelines(lines)
        changed += 1
        print(f"{name:10s} {pipe_z:8.2f} {old_z:15.2f} {pipe_z:8.2f} "
              f"{old_z - pipe_z:+7.2f}")
    print(f"\n{changed} level(s) updated{'  (DRY RUN, nothing written)' if dry else ''}")
    print("turtle now spawns on the start-pipe axis in every level")


if __name__ == "__main__":
    main()
