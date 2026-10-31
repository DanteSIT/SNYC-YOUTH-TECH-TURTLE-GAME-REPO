#!/usr/bin/env python3
"""
Drop every platform onto the seabed as a pile of rocks.

The platforms were thin floating slabs. This measures the floor under each one
and moves it down so the bottom of the rock pile sits on the sand, giving it a
fixed height instead of the old 0.32 m ledge.

Usage:
    python3 tools/ground_platforms.py            # apply
    python3 tools/ground_platforms.py --dry-run  # show what would move
"""

import glob
import os
import re
import subprocess
import sys

from fix_buried import GODOT, transform_line

PILE_HEIGHT = 1.2
LEVELS = sorted(glob.glob("scenes/levels/*.tscn"))
PLATFORM = re.compile(r'^PLATFORM (\S+) (\S+) (\S+) (\S+)$', re.M)


def platforms(level_path):
    out = subprocess.run(
        [GODOT, "--headless", "--path", ".", "--script",
         "res://tools/probe_buried.gd", "--", level_path],
        capture_output=True, text=True).stdout
    return [(name, float(y), float(floor), float(z))
            for name, y, floor, z in PLATFORM.findall(out)]


def main():
    dry = "--dry-run" in sys.argv
    total = 0
    for path in LEVELS:
        found = platforms(path)
        if not found:
            continue
        text = open(path).read()
        moved = 0
        for name, y, floor, z in found:
            hit = transform_line(text, name)
            if hit is None:
                print(f"  {os.path.basename(path)}: no transform for {name}")
                continue
            start, end, args = hit
            new_y = floor + PILE_HEIGHT * 0.5
            args[4] = PILE_HEIGHT
            args[10] = new_y
            text = text[:start] + ", ".join("%.4f" % v for v in args) + text[end:]
            moved += 1
            print(f"  {os.path.basename(path):14s} {name:12s} "
                  f"y {y:6.2f} -> {new_y:6.2f}  (floor {floor:6.2f})")
        if moved and not dry:
            open(path, "w").write(text)
        total += moved
    print(f"\n{total} platform(s) grounded{'  (DRY RUN, nothing written)' if dry else ''}")


if __name__ == "__main__":
    main()
