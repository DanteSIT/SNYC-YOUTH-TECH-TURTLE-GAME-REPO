#!/usr/bin/env python3
"""
Lift collectables, hazards and gates that ended up inside the seabed.

The levels were laid out against the old segmented ground model, but the sand
is now one continuous heightfield, so a few objects sit under the surface. This
runs tools/probe_buried.gd to measure the real floor under each one and raises
just those objects back into reach. Everything else is left alone.

Usage:
    python3 tools/fix_buried.py            # apply
    python3 tools/fix_buried.py --dry-run  # show what would move
"""

import glob
import os
import re
import shutil
import subprocess
import sys

GODOT = os.environ.get("GODOT") or shutil.which("godot") \
    or "/home/dante-pc/Godot_v4.7.2-stable_linux.x86_64"

LEVELS = sorted(glob.glob("scenes/levels/*.tscn"))

# How far above the floor each kind of object should sit.
CLEARANCE = {"Collect": 0.9, "Hazard": 0.5}
GATE_GAP = 0.5          # gap under a low gate wall
MAX_Y = 3.7             # stay under the ceiling

NODE = re.compile(r'^\[node name="([^"]+)" parent="[^"]*"[^\]]*\]$', re.M)
FIX = re.compile(r'^FIX (\w+) (\S+) (\S+) (\S+) (\S+)$', re.M)


def measured(level_path):
    """Ask Godot for (kind, name, y, floor, z) of every buried object."""
    out = subprocess.run(
        [GODOT, "--headless", "--path", ".", "--script",
         "res://tools/probe_buried.gd", "--", level_path],
        capture_output=True, text=True).stdout
    found = []
    for kind, name, y, floor, z in FIX.findall(out):
        found.append((kind, name, float(y), float(floor), float(z)))
    return found


def transform_line(text, name):
    """Return (start, end, args) of the node's transform, or None."""
    m = re.search(r'^\[node name="%s"[^\]]*\]\n' % re.escape(name), text, re.M)
    if not m:
        return None
    # Only look inside this node's own block.
    nxt = text.find("\n[node ", m.end())
    block = text[m.end():nxt if nxt != -1 else len(text)]
    t = re.search(r'^transform = Transform3D\(([^\n]+)\)$', block, re.M)
    if not t:
        return None
    return m.end() + t.start(1), m.end() + t.end(1), \
        [float(v) for v in t.group(1).split(",")]


def main():
    dry = "--dry-run" in sys.argv
    total = 0
    for path in LEVELS:
        fixes = measured(path)
        if not fixes:
            continue
        text = open(path).read()
        moved = 0
        for kind, name, y, floor, z in fixes:
            hit = transform_line(text, name)
            if hit is None:
                print(f"  {os.path.basename(path)}: no transform for {name}")
                continue
            start, end, args = hit
            new_y = floor + CLEARANCE.get(kind, 0.5)
            if kind == "Gate":
                new_y = floor + GATE_GAP + args[4] * 0.5
            new_y = min(new_y, MAX_Y)
            if new_y <= y + 1e-3:
                continue
            args[10] = new_y
            text = text[:start] + ", ".join("%.4f" % v for v in args) + text[end:]
            moved += 1
            print(f"  {os.path.basename(path):14s} {name:12s} {kind:8s} "
                  f"y {y:6.2f} -> {new_y:6.2f}  (floor {floor:6.2f})")
        if moved and not dry:
            open(path, "w").write(text)
        total += moved
    print(f"\n{total} object(s) lifted{'  (DRY RUN, nothing written)' if dry else ''}")


if __name__ == "__main__":
    main()
