#!/usr/bin/env python3
"""
relength.py — rebalance the level-length ladder in the committed level scenes.

The committed scenes already ramp 66m (tutorial) -> 232m (level_15). This tool
flattens that ramp into the agreed tiers.  Target values are the generator's
`level_length` stamp (the value on the GodRays node); the playable pipe span is
always `level_length - 9.4` and the corridor center is always z = 1.3:

    tutorial      66  (unchanged)
    level_1..5  -> 80
    level_6..10 -> 110
    level_11..15-> 140

Per level it symmetrically nudges StartPipe/EndPipe toward the corridor center,
drags the spawn anchor (Turtle) and the goal anchor (Goal + GoalPillarL/R) with
them, and re-stamps the GodRays level_length to the tier length.  Scenery
beyond the new pipes is deliberately left in place — it reads as backdrop past
the pipe mouth and avoids deleting hand-placed work.

Floor/backdrop coverage is checked and, only if the new pipes would poke past
the existing seabed tiles, a Bridging Bed is added at that end.

Idempotent: re-running is a no-op.  Only targeted transform/length lines are
rewritten and edits stay strictly inside the Transform3D(...) argument list —
no reordering, no unique_id churn.

Usage:
    python3 tools/pipeline/relength.py            # apply
    python3 tools/pipeline/relength.py --dry-run  # preview only
    OVERRIDE_TIERS="level_1.tscn:160" python3 tools/pipeline/relength.py  # dev/test
"""
import os
import re
import sys

ROOT = os.environ.get(
    "RELENGTH_ROOT",
    os.path.normpath(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scenes", "levels")
    ),
)

GAP = 9.4          # level_length - pipe span, holds for every committed level
CENTER = 1.3       # corridor center z, holds for every committed level
TURTLE_OFF = -2.6  # player spawn sits this far behind the StartPipe
PIPE_MARGIN = 4.5  # floor/backdrop must extend this far past each pipe mouth

MOVED = ("StartPipe", "EndPipe", "Turtle", "Goal", "GoalPillarL", "GoalPillarR")


def default_tiers():
    tiers = {"tutorial.tscn": 66}
    for i in range(1, 6):
        tiers["level_%d.tscn" % i] = 80
    for i in range(6, 11):
        tiers["level_%d.tscn" % i] = 110
    for i in range(11, 16):
        tiers["level_%d.tscn" % i] = 140
    override = os.environ.get("OVERRIDE_TIERS")
    if override:
        for pair in override.split(";"):
            name, val = pair.split(":")
            tiers[name] = int(val)
    return tiers


def fnum(v):
    """Shortest decimal repr in the style Godot writes to .tscn files."""
    s = "%.3f" % v
    s = s.rstrip("0").rstrip(".")
    if s in ("", "-0"):
        s = "0"
    return s


def find_transform(lines, name):
    """Return (line_idx, prefix, args) for a leaf node's transform, or None."""
    for i, line in enumerate(lines):
        if ('[node name="%s"' % name) in line:
            for j in range(i, min(i + 3, len(lines))):
                m = re.match(r"^(.*?)transform = Transform3D\((.*)\)\s*$", lines[j])
                if m:
                    args = m.group(2).split(",")
                    return j, m.group(1), args
            return None
    return None


def parse_transform_components(args):
    """Return (x, y, z-scale[0-2], pos x, pos y, pos z) lifted from a 12-arg list."""
    z = float(args[8])
    px, py, pz = float(args[9]), float(args[10]), float(args[11])
    return z, px, py, pz


def fmt_transform(prefix, args):
    core = ", ".join(a.strip() for a in args)
    return "%stransform = Transform3D(%s)" % (prefix, core)


def bed_extents(lines):
    """Coverage of the seabed tiles: (start_edge, end_edge, last_bed_line)."""
    start_edge, end_edge = None, None
    last_line = None
    for i, line in enumerate(lines):
        if '[node name="Bed' in line and 'parent="Terrain"' in line:
            for j in range(i, min(i + 3, len(lines))):
                m = re.match(r"^(.*?)transform = Transform3D\((.*)\)\s*$", lines[j])
                if m:
                    args = [a.strip() for a in m.group(2).split(",")]
                    z = float(args[11])
                    sz = float(args[8])
                    top = z + sz / 2.0
                    bot = z - sz / 2.0
                    start_edge = top if start_edge is None else max(start_edge, top)
                    end_edge = bot if end_edge is None else min(end_edge, bot)
                    last_line = j
                    break
    return start_edge, end_edge, last_line


def collect_unique_ids(lines):
    ids = [int(m) for m in re.findall(r"unique_id=(\d+)", "\n".join(lines))]
    return max(ids) + 1 if ids else 1


def bed_instances(lines):
    """Ext instance id string used by the seabed tiles (e.g. o_seabed)."""
    for line in lines:
        if '[node name="Bed' in line:
            m = re.search(r'parent="Terrain"[^]]*instance=ExtResource\("([^"]+)"\)', line)
            if m:
                return m.group(1)
    return None


def add_bed(lines, name, ext_id, uid, z_center, sz, include_uid):
    header = '[node name="%s" parent="Terrain" instance=ExtResource("%s")]' % (name, ext_id)
    if include_uid:
        header = header.replace(" parent=\"Terrain\"", " parent=\"Terrain\" unique_id=%d" % uid)
    transform = fmt_transform("", ["13", "0", "0", "0", "6", "0", "0", "0",
                                   fnum(sz), "-1.5", "-3", fnum(z_center)])
    return [header, transform, ""]


def ensure_floor(lines, new_start, new_end):
    """Grow beds outward only when pipes would poke past current coverage."""
    start_edge, end_edge, last_line = bed_extents(lines)
    if start_edge is None:
        return lines, "\n"
    ext_id = bed_instances(lines)
    uid = collect_unique_ids(lines)
    include_uid = any("unique_id=" in l and '[node name="Bed' in l for l in lines)
    need_start = new_start + PIPE_MARGIN
    need_end = new_end - PIPE_MARGIN
    adds = []
    next_bed = 1
    while any('[node name="Bed%d"' % next_bed in l for l in lines):
        next_bed += 1
    if need_start > start_edge + 1e-4:
        sz = need_start - start_edge
        z_center = (need_start + start_edge) / 2.0
        adds.append(add_bed(lines, "Bed%d" % next_bed, ext_id, uid, z_center, sz, include_uid))
        next_bed += 1
        uid += 1
    if need_end < end_edge - 1e-4:
        sz = end_edge - need_end
        z_center = (need_end + end_edge) / 2.0
        adds.append(add_bed(lines, "Bed%d" % next_bed, ext_id, uid, z_center, sz, include_uid))
        next_bed += 1
    if not adds:
        return lines, ""
    insert_at = (last_line + 1) if last_line is not None else len(lines)
    out = list(lines)
    for block in reversed(adds):
        out[insert_at:insert_at] = block
    return out, " +%d bed tile(s)" % len(adds)


def node_z(args):
    return float(args[11].strip())


def main():
    dry = "--dry-run" in sys.argv
    tiers = default_tiers()
    changed = 0
    for name in sorted(tiers):
        path = os.path.join(ROOT, name)
        if not os.path.exists(path):
            print("SKIP %s (missing)" % name)
            continue
        target = tiers[name]
        with open(path, "r", encoding="utf-8") as f:
            orig = f.read()
        lines = orig.split("\n")

        cur = {}
        for n in MOVED:
            r = find_transform(lines, n)
            if r is None:
                print("FAIL %s: %s transform not found" % (name, n))
                return 1
            cur[n] = (r[0], r[1], r[2])
        ws = find_transform(lines, "WaterSurface")
        # WaterSurface was removed from committed levels (strip pass); the
        # level_length stamp on GodRays is the authoritative length.
        ll_i, ll_len = None, 0
        for i, line in enumerate(lines):
            m = re.match(r"\s*level_length = (\d+)", line)
            if m:
                ll_i, ll_len = i, int(m.group(1))
                break

        start = node_z(cur["StartPipe"][2])
        end = node_z(cur["EndPipe"][2])
        span = start - end

        if ll_len == target and abs(start - (CENTER + (target - GAP) / 2.0)) < 1e-3:
            print("NOCHANGE %s (already %d)" % (name, target))
            continue

        new_span = target - GAP
        new_start = CENTER + new_span / 2.0
        new_end = CENTER - new_span / 2.0
        targets = {
            "StartPipe": new_start,
            "EndPipe": new_end,
            "Turtle": new_start + TURTLE_OFF,
            "Goal": new_end,
            "GoalPillarL": new_end,
            "GoalPillarR": new_end,
        }
        for n, new_z in targets.items():
            idx, prefix, args = cur[n]
            args[11] = fnum(new_z)
            lines[idx] = fmt_transform(prefix, args)

        # WaterSurface was removed from committed levels; the GodRays
        # level_length stamp is the authoritative length.

        # GodRays level_length stamp
        if ll_i is not None:
            lines[ll_i] = re.sub(r"level_length = \d+", "level_length = %d" % target, lines[ll_i])

        lines, bed_note = ensure_floor(lines, new_start, new_end)

        text = "\n".join(lines)
        if text == orig:
            print("NOCHANGE %s (computed no-op)" % name)
            continue

        n_out_c, n_out_g = 0, 0
        for i, l in enumerate(lines):
            if not re.match(r'\[node name="(Collect|Gate)\d+"', l):
                continue
            z = 1e9
            if i + 1 < len(lines):
                m = re.search(r"transform = Transform3D\(([^)]*)\)", lines[i + 1])
                if m:
                    z = float(m.group(1).split(",")[11].strip())
            if l.startswith('[node name="Collect') and (z > new_start or z < new_end):
                n_out_c += 1
            elif l.startswith('[node name="Gate') and (z > new_start or z < new_end):
                n_out_g += 1
        if dry:
            print("DRY %s: %d -> %d (span %.1f -> %.1f)%s" % (name, ll_len, target, span, new_span, bed_note))
        else:
            with open(path, "w", encoding="utf-8") as f:
                f.write(text)
            print("RELENGTH %s: %d -> %d (span %.1f -> %.1f, %d collect / %d gate past pipes as backdrop)%s"
                  % (name, ll_len, target, span, new_span, n_out_c, n_out_g, bed_note))
            changed += 1
    print("done, %d level(s) updated" % changed)
    return 0


if __name__ == "__main__":
    sys.exit(main() or 0)