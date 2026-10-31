#!/usr/bin/env python3
"""
Remove the hard ceiling from the level scenes.

The turtle is kept in bounds by a gentle downward force now, so the invisible
ceiling collider is gone. This strips the Ceiling body, its shape and the
matching sub-resource from every level, and fixes the load_steps count.

Usage:
    python3 tools/remove_ceiling.py
"""

import glob
import re

CEILING = re.compile(r'^\[node name="Ceiling"[^\]]*\]\n(?:[^\[\n][^\n]*\n)*', re.M)
CEILING_SHAPE = re.compile(
    r'^\[node name="CollisionShape3D"[^\]]*parent="Ceiling"[^\]]*\]\n(?:[^\[\n][^\n]*\n)*',
    re.M)
SHAPE_RES = re.compile(
    r'^\[sub_resource type="BoxShape3D" id="ceiling_shape"\]\n(?:[^\[\n][^\n]*\n)*',
    re.M)
LOAD_STEPS = re.compile(r'load_steps=(\d+)')


def main():
    total = 0
    for path in sorted(glob.glob("scenes/levels/*.tscn")):
        text = open(path).read()
        if 'name="Ceiling"' not in text:
            continue
        text = CEILING.sub("", text)
        text = CEILING_SHAPE.sub("", text)
        text, removed = SHAPE_RES.subn("", text)
        match = LOAD_STEPS.search(text)
        if removed and match:
            steps = int(match.group(1))
            text = LOAD_STEPS.sub(f"load_steps={steps - 1}", text, count=1)
        open(path, "w").write(text)
        total += 1
        print(f"  {path}: ceiling removed")
    print(f"\n{total} level(s) cleared")


if __name__ == "__main__":
    main()
