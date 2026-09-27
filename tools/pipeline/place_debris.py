#!/usr/bin/env python3
"""
place_debris.py — bring the ambient debris pockets inside each pipe span.

The ocean litter (ocean_particles.tscn: the flotsam kit — bag films, cans, cork
bobbers, wood, kelp, gleam chips) is instanced per level as OceanParticles1..3. After relength.py shortened the pipe
spans, the outermost pockets were left floating past the sealed pipe mouths,
out of reach and out of sight.  This pass repositions each pocket onto the
player's swim line (x=0, y=0.8 — the spawn box spans the swim height so the
turtle swims *through* the litter) and at symmetric slices of the corridor:

    z = [CENTER - span/4, CENTER, CENTER + span/4]

It rewrites only the OceanParticles instance transforms (canonical identity
rotation + new origin), nothing else — same .tscn rules as relength.py.

Idempotent: re-running is a no-op.

Usage:
    python3 tools/pipeline/place_debris.py            # apply
    python3 tools/pipeline/place_debris.py --dry-run  # preview only
"""
import os
import re
import sys

ROOT = os.environ.get(
    "DEBRIS_ROOT",
    os.path.normpath(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scenes", "levels")
    ),
)

CENTER = 1.3       # corridor center z, holds for every committed level
POCKET_Y = 0.8     # swim-line height (spawn box is 2.2 tall -> spans -0.3..1.9)

LEVELS = ["tutorial.tscn"] + ["level_%d.tscn" % i for i in range(1, 16)]

NODE_RE = re.compile(r'^\[node name="([^"]+)"')
TRANS_RE = re.compile(r"^(.*?)transform = Transform3D\((.*)\)\s*$")
POCKET_RE = re.compile(r"^OceanParticles(\d+)$")


def fnum(v):
    s = "%.3f" % v
    s = s.rstrip("0").rstrip(".")
    if s in ("", "-0"):
        s = "0"
    return s


def node_blocks(lines):
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


def pocket_pairs(lines, blocks):
    """(name, line_idx, prefix) pairs for every OceanParticlesN transform."""
    out = []
    for s, e in blocks:
        name = block_name(lines, s)
        if name is None or not POCKET_RE.match(name):
            continue
        t = block_transform(lines, s, e)
        if t and len(t[2]) >= 12:
            out.append((name, t[0], t[1]))
    out.sort(key=lambda p: int(POCKET_RE.match(p[0]).group(1)))
    return out


def target_transform(z):
    return "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %s, %s)" % (fnum(POCKET_Y), fnum(z))


def main():
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
        blocks = node_blocks(lines)
        lo, hi = find_pipes(lines, blocks)
        if lo is None or hi is None:
            print("SKIP %s (no pipe transforms)" % name)
            continue
        span = hi - lo
        slices = sorted([CENTER - span / 4.0, CENTER, CENTER + span / 4.0])
        pockets = pocket_pairs(lines, blocks)
        if not pockets:
            print("SKIP %s (no OceanParticles)" % name)
            continue

        edits = 0
        for k, (pname, lidx, prefix) in enumerate(pockets):
            tz = slices[k % len(slices)]
            newline = prefix + "transform = " + target_transform(tz)
            if lines[lidx] != newline:
                lines[lidx] = newline
                edits += 1

        text = "\n".join(lines)
        if text == orig:
            print("NOCHANGE %s" % name)
            continue
        if dry:
            print("DRY %s: %d pocket(s) -> z in [%s]" % (
                name, edits, ", ".join(fnum(z) for z in slices)))
        else:
            with open(path, "w", encoding="utf-8") as f:
                f.write(text)
            print("DEBRIS %s: %d pocket(s) -> z in [%s]" % (
                name, edits, ", ".join(fnum(z) for z in slices)))
            changed += 1
    print("done, %d level(s) updated" % changed)
    return 0


if __name__ == "__main__":
    sys.exit(main() or 0)