#!/usr/bin/env python3
"""
retune_grading.py — one-off, applies the gamma/brightness reduction to every level.

The corridor read as washed out for four compounding reasons, all of them in the
per-level Environment or the DepthFog node:

  * `volumetric_fog_emission_energy = 0.18` is a CONSTANT emission term added to
    the volumetric fog, so the water itself glowed slightly everywhere. This is
    the single biggest source of the milky look.
  * `glow_intensity` 0.7-1.0 with `glow_hdr_threshold` 0.85-1.0 meant nearly the
    whole frame qualified for bloom.
  * The PanoramaSkyMaterial ran at `energy_multiplier = 1.15`.
  * `ambient_light_source = 2` is a FLAT colour term (not a sky probe), so
    `ambient_light_energy` 0.62-0.74 with a near-white blue lifted every surface
    off black regardless of how it was lit.

Each key is scaled by a fixed factor rather than set to a constant, so the four
depth tiers (shallow / mid / deep / deepest) keep their relative relationship
instead of collapsing to one flat look.

Run once; the levels are edited in place. Re-running is idempotent because every
transform is a multiplication, and the values are already scaled past 1.0 for
tonemap_white... except that one, so it is guarded (see TONEMAP_WHITE_ADD).

Usage:
    python3 tools/retune_grading.py           # apply
    python3 tools/retune_grading.py --dry     # report only
"""
import glob
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

# Multiply these. Anything not listed is left alone.
ENV_SCALE = {
    "ambient_light_energy": 0.70,   # flat ambient lifting every surface off black
    "glow_intensity": 0.55,         # far less bloom
    "glow_bloom": 0.60,
    "glow_levels/3": 0.70,
    "glow_levels/4": 0.70,
    "fog_sun_scatter": 0.55,
    "tonemap_exposure": 0.86,
}

# Additive. tonemap_white is a divisor inside Godot's ACES fit, so RAISING it
# darkens the image. Additive and multiplicative transforms both compound, so
# the Environment block is stamped with MARKER on the first pass and any level
# carrying the marker is skipped entirely on a second run.
ENV_ADD = {
    "tonemap_white": 0.4,
}
TONEMAP_WHITE_ADD = ENV_ADD["tonemap_white"]
MARKER = "; grading retuned by tools/retune_grading.py"

# Volumetric fog emission is set absolutely, not scaled: any non-zero value adds a
# uniform haze, so it needs a floor rather than a ratio.
ENV_SET = {
    "volumetric_fog_emission_energy": 0.04,
}

# Floor for glow_hdr_threshold: below ~1.0 most of the frame blooms.
ENV_FLOOR = {
    "glow_hdr_threshold": 1.15,
}

# The sky backdrop, shared by all levels via a PanoramaSkyMaterial sub-resource.
SKY_SCALE = {"energy_multiplier": 0.74}

# DepthFog node exports. depth_fog.gd writes fog_light_color, fog_light_energy,
# background_color and ambient_light_color into the Environment every frame, so
# the level's env values for those are dead -- these are the ones that count.
FOG_SCALE = {
    "start_fog_energy": 0.70,
    "end_fog_energy": 0.70,
    "start_fog_density": 0.90,
    "end_fog_density": 0.90,
}
FOG_COLOR_SCALE = {
    "start_fog": 0.85,
    "end_fog": 0.85,
    "start_ambient": 0.80,
    "end_ambient": 0.80,
    "start_bg": 0.80,
    "end_bg": 0.80,
}


def block(lines: list[str], header_pattern: str) -> tuple[int, int]:
    """Return (start, end) of the sub-resource/node block whose header matches.

    Operates on the caller's list in place. It must NOT be handed the raw text
    separately per block: an earlier version of this script re-split the text for
    each block, so the last block's list was the only one written back and every
    earlier edit was silently discarded.
    """
    for i, l in enumerate(lines):
        if re.match(header_pattern, l):
            j = i + 1
            while j < len(lines) and not lines[j].startswith("["):
                j += 1
            return i, j
    return -1, -1


def scale_num(line: str, key: str, factor: float) -> str:
    m = re.match(r"(%s = )(-?[\d.]+)$" % re.escape(key), line)
    if not m:
        return line
    v = float(m.group(2)) * factor
    return "%s%s" % (m.group(1), round(v, 4))


def add_num(line: str, key: str, delta: float) -> str:
    m = re.match(r"(%s = )(-?[\d.]+)$" % re.escape(key), line)
    if not m:
        return line
    v = float(m.group(2)) + delta
    return "%s%s" % (m.group(1), round(v, 4))


def floor_num(line: str, key: str, lo: float) -> str:
    m = re.match(r"(%s = )(-?[\d.]+)$" % re.escape(key), line)
    if not m:
        return line
    v = max(float(m.group(2)), lo)
    return "%s%s" % (m.group(1), round(v, 4))


def scale_color(line: str, key: str, factor: float) -> str:
    m = re.match(r"(%s = Color\()([\d.]+), ([\d.]+), ([\d.]+)(.*)$" % re.escape(key), line)
    if not m:
        return line
    r, g, b = (float(m.group(i)) * factor for i in (2, 3, 4))
    return "%s%.4f, %.4f, %.4f%s" % (m.group(1), min(r, 1.0), min(g, 1.0), min(b, 1.0), m.group(5))


def apply_block(lines, start, end, scale, add=None, setv=None, floor=None,
                color_scale=None):
    """Rewrite key=value lines in lines[start:end] in place."""
    changes = []
    for i in range(start, end):
        orig = lines[i]
        out = orig
        for k, f in scale.items():
            out = scale_num(out, k, f)
        for k, d in (add or {}).items():
            out = add_num(out, k, d)
        for k, v in (setv or {}).items():
            m = re.match(r"(%s = )-?[\d.]+$" % re.escape(k), out)
            if m:
                out = "%s%s" % (m.group(1), v)
        for k, lo in (floor or {}).items():
            out = floor_num(out, k, lo)
        for k, f in (color_scale or {}).items():
            out = scale_color(out, k, f)
        if out != orig:
            lines[i] = out
            changes.append((orig.strip(), out.strip()))
    return changes


def main() -> None:
    dry = "--dry" in sys.argv
    for path in sorted(glob.glob(os.path.join(ROOT, "scenes", "levels", "*.tscn"))):
        rel = os.path.relpath(path, ROOT)
        text = open(path, encoding="utf-8").read()
        if MARKER in text:
            print("=== %s  (already retuned, skipped)" % rel)
            continue

        # One list for the whole file. Every block is located against it and the
        # result is written back exactly once, so no edit can be lost.
        lines = text.split("\n")
        report = []

        # Locate everything up front, then edit in REVERSE document order:
        # the Environment edit inserts a marker line, which would otherwise shift
        # the indices of any block that came after it.
        targets = [
            ('sky', r'^\[sub_resource type="PanoramaSkyMaterial"'),
            ("env", r'^\[sub_resource type="Environment"'),
            ("fog", r'^\[node name="DepthFog"'),
        ]
        found = []
        for name, pat in targets:
            s, e = block(lines, pat)
            if s >= 0:
                found.append((s, e, name, pat))
        found.sort(key=lambda t: t[0], reverse=True)

        for s, e, name, pat in found:
            if name == "sky":
                c = apply_block(lines, s, e, SKY_SCALE)
            elif name == "env":
                c = apply_block(lines, s, e, ENV_SCALE, add=ENV_ADD,
                                setv=ENV_SET, floor=ENV_FLOOR)
                # level_1 omits tonemap_exposure entirely and so inherits the 1.0
                # default; the scale above is a no-op on a key that is not there.
                if not any(l.startswith("tonemap_exposure") for l in lines[s:e]):
                    lines.insert(e, "tonemap_exposure = 0.86")
                    c.append(("tonemap_exposure (was absent, default 1.0)",
                              "tonemap_exposure = 0.86"))
                lines.insert(s + 1, MARKER)
            else:
                c = apply_block(lines, s, e, FOG_SCALE, color_scale=FOG_COLOR_SCALE)
            report += [("%s %s" % (name, a), b) for a, b in c]

        if report:
            print("=== %s" % rel)
            for a, b in report:
                print("    %-52s -> %s" % (a, b))
        if not dry:
            open(path, "w", encoding="utf-8").write("\n".join(lines))
    print("done%s" % (" (dry run, nothing written)" if dry else ""))


if __name__ == "__main__":
    main()
