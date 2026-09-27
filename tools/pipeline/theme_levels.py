#!/usr/bin/env python3
"""
theme_levels.py — retune the per-level DepthFog palettes in the committed level
scenes into a coherent warm->cool dive arc.

The committed scenes already carry 4 tiers of DepthFog overrides (shallow/mid/
deep/abyss). This pass fixes the weakest tier (shallow, tutorial + level_1..3)
which previously read as a cold mid-blue instead of bright warm sunlit shallows,
and warms the mid tier (level_4..7) so the full arc reads:
    warm bright shallows -> green-teal mid -> cold deep blue -> dark abyss

Tiers (node name prefixes matching each file name):
    shallow: tutorial, level_1, level_2, level_3
    mid:     level_4 .. level_7
    deep:    level_8 .. level_11   (left unchanged — already distinct)
    abyss:   level_12 .. level_15  (left unchanged — already distinct)

Run:  python3 tools/pipeline/theme_levels.py
Idempotent: only rewrites files that actually change, and only the DepthFog
property lines listed below. Follows the .tscn rewrite rules: line-targeted
edits, never re-orders, never touches transforms or unique_id.
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scenes", "levels")
ROOT = os.path.normpath(ROOT)

LEVELS = ["tutorial.tscn"] + ["level_%d.tscn" % i for i in range(1, 16)]


def fmt_c(color):
    return "Color(%.3f, %.3f, %.3f, %d)" % (color[0], color[1], color[2], 1)


def fmt_f(v):
    return "%.4f" % v


SHALLOW = {
    "start_fog": fmt_c((0.80, 0.95, 0.93)),
    "end_fog": fmt_c((0.58, 0.80, 0.87)),
    "start_bg": fmt_c((0.38, 0.68, 0.63)),
    "end_bg": fmt_c((0.22, 0.50, 0.51)),
    "start_ambient": fmt_c((0.92, 1.00, 0.96)),
    "end_ambient": fmt_c((0.80, 0.94, 0.95)),
    "start_fog_energy": fmt_f(1.25),
    "end_fog_energy": fmt_f(1.00),
    "start_fog_density": fmt_f(0.0018),
    "end_fog_density": fmt_f(0.0055),
    "start_vol_density": fmt_f(0.0020),
    "end_vol_density": fmt_f(0.0035),
    "start_overlay_depth": fmt_f(0.08),
    "end_overlay_depth": fmt_f(0.40),
}

MID = {
    "start_fog": fmt_c((0.62, 0.86, 0.90)),
    "end_fog": fmt_c((0.40, 0.66, 0.80)),
    "start_bg": fmt_c((0.22, 0.56, 0.56)),
    "end_bg": fmt_c((0.12, 0.40, 0.46)),
    "start_ambient": fmt_c((0.78, 0.95, 0.95)),
    "end_ambient": fmt_c((0.62, 0.82, 0.88)),
    "start_fog_energy": fmt_f(1.00),
    "end_fog_energy": fmt_f(0.78),
    "start_fog_density": fmt_f(0.0035),
    "end_fog_density": fmt_f(0.0085),
    "start_vol_density": fmt_f(0.0030),
    "end_vol_density": fmt_f(0.0045),
    "start_overlay_depth": fmt_f(0.20),
    "end_overlay_depth": fmt_f(0.50),
}

# tiers not listed here keep their committed values
TIERS = {"tutorial.tscn": SHALLOW, "level_3.tscn": SHALLOW, "level_2.tscn": SHALLOW, "level_1.tscn": SHALLOW}
for i in range(4, 8):
    TIERS["level_%d.tscn" % i] = MID

TIER_NAMES = {"tutorial.tscn": "shallow", "level_1.tscn": "shallow", "level_2.tscn": "shallow",
              "level_3.tscn": "shallow", "level_4.tscn": "mid", "level_5.tscn": "mid",
              "level_6.tscn": "mid", "level_7.tscn": "mid"}

PROPS = list(SHALLOW.keys())


def tier_for(name):
    return TIERS.get(name)


def main():
    changed = 0
    for name in LEVELS:
        path = os.path.join(ROOT, name)
        if not os.path.exists(path):
            print("SKIP %s (missing)" % name)
            continue
        tier = tier_for(name)
        if tier is None:
            print("SKIP %s (no tier)" % name)
            continue
        with open(path, "r", encoding="utf-8") as f:
            lines = f.read().split("\n")
        in_block = False
        new_lines = list(lines)
        for i, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith("[node") and 'name="DepthFog"' in stripped:
                in_block = True
                continue
            if in_block:
                if stripped == "" or stripped.startswith("[node") or stripped.startswith("[sub_resource"):
                    in_block = False
                else:
                    m = re.match(r"^(\s*)(start_fog|end_fog|start_bg|end_bg|start_ambient|end_ambient|"
                                 r"start_fog_energy|end_fog_energy|start_fog_density|end_fog_density|"
                                 r"start_vol_density|end_vol_density|start_overlay_depth|end_overlay_depth)\s*=.*$", line)
                    if m and m.group(2) in tier:
                        new_lines[i] = "%s%s = %s" % (m.group(1), m.group(2), tier[m.group(2)])
        text = "\n".join(new_lines)
        if text != "\n".join(lines):
            with open(path, "w", encoding="utf-8") as f:
                f.write(text)
            changed += 1
            print("THEME %s -> %s tier" % (name, TIER_NAMES.get(name, "?")))
        else:
            print("NOCHANGE %s" % name)
    print("done, %d level(s) updated" % changed)
    return 0 if changed >= 0 else 1


if __name__ == "__main__":
    sys.exit(main())