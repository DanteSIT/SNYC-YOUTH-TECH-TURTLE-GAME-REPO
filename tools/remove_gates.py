#!/usr/bin/env python3
"""
Remove the gate obstacles from the level scenes.

Gates are switched off for now. The generator no longer creates them, and this
clears the ones already baked into the scenes. The obstacle scene itself stays,
because the goal posts still use it.

Usage:
    python3 tools/remove_gates.py
"""

import glob
import re

GATE = re.compile(r'^\[node name="Gate\d+"[^\]]*\]\n(?:[^\[\n][^\n]*\n)*', re.M)


def main():
    total = 0
    for path in sorted(glob.glob("scenes/levels/*.tscn")):
        text = open(path).read()
        text, removed = GATE.subn("", text)
        if removed:
            open(path, "w").write(text)
            total += removed
            print(f"  {path}: removed {removed}")
    print(f"\n{total} gate(s) removed")


if __name__ == "__main__":
    main()
