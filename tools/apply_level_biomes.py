#!/usr/bin/env python3
"""Edit the 16 level scenes:
  1) drop the floating 'Roof' rocks and ceiling 'Moss' props,
  2) point each level's 5 vegetation ext_resources at its own biome variant,
  3) rotate the Hazard nodes across the 5 hazard-litter scenes.
Python-only text block edit (Godot ignores a stale load_steps hint).
"""
import os, re, sys

PROJ = "/home/dante-pc/Godot/turtle-godot-v-0.1"
LVL = os.path.join(PROJ, "scenes/levels")
APPLY = "--apply" in sys.argv

# (kelp, fan, sponge, star, urchin) suffixes; level 1 + tutorial keep the defaults
BIOME = {
    1: ("", "", "", "", ""),
    2: ("_b", "_b", "_b", "_b", "_b"),
    3: ("_c", "", "_c", "_c", ""),
    4: ("_b", "_c", "", "", "_c"),
    5: ("", "_b", "_c", "_c", "_b"),
    6: ("_c", "_c", "_b", "", "_b"),
    7: ("_b", "", "_b", "_b", ""),
    8: ("", "_c", "_c", "_b", "_c"),
    9: ("_c", "_b", "", "_c", "_b"),
    10: ("_b", "_b", "", "", "_c"),
    11: ("", "_c", "_b", "_c", "_b"),
    12: ("_c", "_c", "_b", "_c", ""),
    13: ("_b", "_c", "_c", "", "_b"),
    14: ("", "_b", "", "_c", "_c"),
    15: ("_c", "", "_c", "_b", "_b"),
}
# scene basename -> index in the biome tuple
VEG = {"kelp_bed": 0, "sea_fan": 1, "sponge": 2, "starfish": 3, "sea_urchin": 4}

HAZ_VARIANTS = ["hazard", "hazard_bottle", "hazard_can", "hazard_hook", "hazard_net"]
HAZ_ID = {"hazard_bottle": "haz_bottle", "hazard_can": "haz_can",
          "hazard_hook": "haz_hook", "hazard_net": "haz_net"}


def blocks(text):
    out, cur = [], []
    for ln in text.splitlines(keepends=True):
        if ln.startswith("[") and cur:
            out.append("".join(cur))
            cur = [ln]
        else:
            cur.append(ln)
    if cur:
        out.append("".join(cur))
    return out


def node_name(block):
    m = re.match(r'\[node name="([^"]+)"', block)
    return m.group(1) if m else None


def block_y(block):
    m = re.search(r'Transform3D\(([^)]*)\)', block)
    if not m:
        return None
    nums = [float(x) for x in m.group(1).split(",")]
    return nums[10]


def level_index(name):
    if name == "tutorial.tscn":
        return None
    m = re.match(r"level_(\d+)\.tscn$", name)
    return int(m.group(1)) if m else None


for fname in sorted(os.listdir(LVL)):
    if not fname.endswith(".tscn"):
        continue
    path = os.path.join(LVL, fname)
    text = open(path, encoding="utf-8").read()
    idx = level_index(fname)
    suffix = BIOME.get(idx, ("", "", "", "", "")) if idx else ("", "", "", "", "")

    kept = []
    removed_roof = removed_moss = 0
    haz_nodes = []
    for b in blocks(text):
        nm = node_name(b)
        if nm and re.fullmatch(r"Roof\d+", nm):
            removed_roof += 1
            continue
        if nm and re.fullmatch(r"Moss\d+", nm):
            y = block_y(b)
            if y is not None and y > 4.0:
                removed_moss += 1
                continue
        # retarget vegetation ext_resources
        if b.startswith("[ext_resource") and "scenes/objects/" in b:
            m = re.search(r'/scenes/objects/(kelp_bed|sea_fan|sponge|starfish|sea_urchin)\.tscn"', b)
            if m:
                base = m.group(1)
                sfx = suffix[VEG[base]]
                b = b.replace(f"/scenes/objects/{base}.tscn", f"/scenes/objects/{base}{sfx}.tscn")
        if b.startswith("[ext_resource") and "path=\"res://scenes/objects/hazard.tscn\"" in b:
            haz_id = re.search(r'id="([^"]+)"', b).group(1)
        kept.append(b)

    # hazard variant rotation
    haz_id = re.search(r'path="res://scenes/objects/hazard\.tscn" id="([^"]+)"', text).group(1)
    start = ((idx or 1) - 1) % 5
    needed = []
    assigned = []
    for b in kept:
        nm = node_name(b)
        if nm and re.fullmatch(r"Hazard\d+", nm):
            v = (start + len(assigned)) % 5
            assigned.append(HAZ_VARIANTS[v])
            if HAZ_VARIANTS[v] != "hazard":
                needed.append(HAZ_VARIANTS[v])
    out = []
    for b in kept:
        nm = node_name(b)
        if nm and re.fullmatch(r"Hazard\d+", nm) and assigned:
            v = assigned.pop(0)
            eid = haz_id if v == "hazard" else HAZ_ID[v]
            b = re.sub(r'instance=ExtResource\("[^"]+"\)', f'instance=ExtResource("{eid}")', b)
            out.append(b)
            continue
        out.append(b)
    # insert the needed hazard ext_resources right after the bag one
    ins = []
    for v in dict.fromkeys(needed):
        if f'id="{HAZ_ID[v]}"' not in text:
            ins.append(f'[ext_resource type="PackedScene" path="res://scenes/objects/{v}.tscn" id="{HAZ_ID[v]}"]\n')
    if ins:
        for i, b in enumerate(out):
            if b.startswith("[ext_resource") and "path=\"res://scenes/objects/hazard.tscn\"" in b:
                out[i:i + 1] = [b] + ins
                break
    new = "".join(out)
    changed = (removed_roof or removed_moss or suffix != ("", "", "", "", "") or needed)
    n_haz = sum(1 for b in out if node_name(b) and re.fullmatch(r"Hazard\d+", node_name(b)))
    picks = [HAZ_VARIANTS[(start + i) % 5] for i in range(n_haz)]
    print(f"{fname:16} biome={''.join(s or 'A' for s in suffix)} roof-={removed_roof:3} moss-={removed_moss:2} haz={picks}")
    if APPLY and changed:
        open(path, "w", encoding="utf-8").write(new)
if not APPLY:
    print("\n(dry run; pass --apply to write)")
