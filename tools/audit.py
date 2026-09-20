#!/usr/bin/env python3
"""Static pacing audit: tallies hazards/gates/platforms/jelly/fish/reef/boss per
committed level scene (by node name pattern) and reports per-10 m density ratings.
No scene files are modified.  python3 tools/audit.py prints the table.
Report is documented in docs/PACING_AUDIT.md.
"""
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..", "scenes", "levels")
LEVELS = sorted(f for f in os.listdir(ROOT) if re.fullmatch(r"(?:level_\d+|tutorial)\.tscn", f))

TRANSFORM = re.compile(r"transform = Transform3D\([^\)]+\)")


def xyz_of(t: str):
    """returns (x, y, z) position fields of a Transform3D line, or None."""
    if t is None:
        return None
    m = re.search(r"Transform3D\([^\)]+,\s*([\d.\-]+),\s*([\d.\-]+),\s*([\d.\-]+)\)$", t.strip())
    if not m:
        return None
    return tuple(float(v) for v in m.groups())


def parse(path: str) -> dict:
    with open(path) as fh:
        text = fh.read()
    blocks = re.split(r"^(?=\[node\s)", text, flags=re.MULTILINE)
    start_z = end_z = None
    gates = []
    gate_y = []
    n_haz = 0
    n_jelly = 0
    n_fish = 0
    n_reef = 0
    n_rock = 0
    n_plat = 0
    n_collect = 0
    n_boss = 0
    for b in blocks:
        nm = re.search(r'\[node name="([^"]+)"', b)
        name = nm.group(1) if nm else ""
        tm = TRANSFORM.search(b)
        t = tm.group(0) if tm else None
        pos = xyz_of(t)
        if name == "StartPipe" and pos is not None:
            start_z = pos[2]
        elif name == "EndPipe" and pos is not None:
            end_z = pos[2]
        elif name.startswith("Gate"):
            gates.append(pos[2] if pos else None)
            if pos:
                gate_y.append(pos[1])
        elif name.startswith("Hazard"):
            n_haz += 1
        elif name.startswith("Jellyfish"):
            n_jelly += 1
        elif name.startswith("FishHome"):
            n_fish += 1
        elif name.startswith("Reef"):
            n_reef += 1
        elif name.startswith("Rock"):
            n_rock += 1
        elif name.startswith("Platform") and "CollectPlat" not in name:
            n_plat += 1
        elif name.startswith("Collect") and "CollectPlat" not in name:
            n_collect += 1
        elif "Boss" in name:
            n_boss += 1

    span = abs(start_z - end_z) if start_z is not None and end_z is not None else 0
    gz = sorted((g for g in gates if g is not None), reverse=True)
    min_gap = None
    if len(gz) > 1:
        min_gap = min(gz[i] - gz[i + 1] for i in range(len(gz) - 1))
    return dict(span=span, gates=len(gz), gate_y=gate_y or None, hazards=n_haz,
                jellies=n_jelly, schools=n_fish, reefs=n_reef, rocks=n_rock,
                platforms=n_plat, collects=n_collect, bosses=n_boss, min_gap=min_gap)


def phase(lvl: int) -> str:
    if lvl == 0:
        return "TUTORIAL"
    if lvl in (1, 2):
        return "WARM"
    if lvl in (3, 4):
        return "CALIBRATE"
    if lvl in (5, 6, 7):
        return "CHALLENGE"
    if lvl in (8, 9):
        return "REST"
    if lvl in (10, 11, 12, 13, 14):
        return "CRESCENDO"
    return "FINAL"


def main() -> dict:
    rows = {}
    print(f"{'level':<13}{'span':>5}{'gates':>6}{'gateY':>13}{'haz':>5}{'jelly':>6}{'fish':>6}{'reef':>5}{'rock':>6}{'plat':>5}{'boss':>5}{'collect':>7}")
    for f in LEVELS:
        s = parse(os.path.join(ROOT, f))
        rows[f] = s
        y = "—" if not s["gate_y"] else "%.1f-%.1f" % (min(s["gate_y"]), max(s["gate_y"]))
        print(f"{f:<13}{s['span']:>5.0f}{s['gates']:>6}{y:>13}{s['hazards']:>5}{s['jellies']:>6}{s['schools']:>6}{s['reefs']:>5}{s['rocks']:>6}{s['platforms']:>5}{s['bosses']:>5}{s['collects']:>7}")
    print("\nDENSITY (haz+gates per 10 m) by planned phase:")
    for f, s in rows.items():
        if f == "tutorial.tscn":
            continue
        lvl = int(re.search(r"\d+", f).group())
        d = (s["hazards"] + s["gates"]) / max(s["span"], 1) * 10.0
        print(f"  {f:<13} {d:5.2f}  [{phase(lvl)}]")
    return rows


if __name__ == "__main__":
    main()