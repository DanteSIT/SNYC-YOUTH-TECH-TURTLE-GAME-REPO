#!/usr/bin/env python3
"""Author (a) per-biome vegetation wrapper variants and (b) hazard model scenes.

Vegetation variants keep the base-at-origin + level-applies-scale convention of
the originals, so a level only has to point its ext_resource at a different file.
Hazard scenes centre the model on the Area3D origin and fit a box collision to the
scaled AABB, so the level instance transforms stay meaningful.
"""
import math, os, re

PROJ = "/home/dante-pc/Godot/turtle-godot-v-0.1"
VEG = os.path.join(PROJ, "assets/models/vegetation")
HAZ = os.path.join(PROJ, "assets/models/hazard")
OBJ = os.path.join(PROJ, "scenes/objects")

# ---- measured AABBs (position, size) of the imported models -----------------
MODELS = {
    "kelp_a":     ((-0.563, -1.115, -0.674), (1.188, 2.299, 1.076)),
    "kelp_b":     ((-0.142, -0.416, -0.242), (0.280, 0.817, 0.384)),
    "kelp_c":     ((-1.019, -0.016, -1.094), (2.180, 5.591, 2.136)),
    "seafan_a":   ((-0.749, -0.617, -1.208), (2.457, 1.924, 2.416)),
    "fan_b":      ((-47.39104, -0.000012, -47.93624), (89.98058, 131.369, 96.55291)),
    "fan_c":      ((-1.113775, -1.139, -0.908114), (1.876305, 1.892189, 1.736224)),
    "sponge_a":   ((-1.194, -0.009, -1.800), (2.392, 0.919, 3.587)),
    "sponge_b":   ((-8.004, 0.000, -10.500), (16.187, 5.475, 21.000)),
    "sponge_c":   ((-661339.4, 393073.9, 303222.2), (319956.4, 75304.0, 164287.2)),
    "starfish_a": ((-6.105, 0.000, -7.709), (8.371, 0.761, 10.307)),
    "star_b":     ((-0.951736, -0.809596, -0.261911), (1.903472, 1.810311, 0.523822)),
    "star_c":     ((-0.42581, -0.372705, -0.168345), (0.851619, 0.809938, 0.33669)),
    "urchin_a":   ((-3.277, -2.977, -3.912), (6.556, 5.963, 7.794)),
    "urchin_b":   ((-0.418, -0.296, -0.437), (0.821, 0.690, 0.758)),
    "urchin_c":   ((-0.361016, -0.296413, -0.429758), (0.785682, 0.689709, 0.705981)),
}

HAZ_MODELS = {
    "bag":    ((-0.249016, -0.01144, -0.250825), (0.496877, 0.563712, 0.503335)),
    "bottle": ((-0.225838, -0.001084, -0.225838), (0.451676, 1.563806, 0.451676)),
    "can":    ((-0.11232, 0.0, -0.11232), (0.22464, 0.33, 0.22464)),
    "hook":   ((-37.507, 0.0, -5.4267), (89.9553, 224.8715, 10.8534)),
    "net":    ((-0.460639, -0.559396, -2.116231), (0.921279, 0.628388, 3.651912)),
}


def fmt(v):
    r = round(v, 6)
    if r == 0:
        return "0"
    return ("%.6f" % r).rstrip("0").rstrip(".")


def rot_y(size, yaw_deg):
    """Half-extent AABB size after rotating the box about Y."""
    th = math.radians(yaw_deg)
    ct, st = abs(math.cos(th)), abs(math.sin(th))
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    return (2 * (ct * hx + st * hz), size[1], 2 * (st * hx + ct * hz))


def veg_transform(model, target, yaw_deg, ox, oz, mode="height"):
    pos, size = MODELS[model]
    if mode == "footprint":
        s = target / max(size[0], size[2])
    else:
        s = target / size[1]
    cx, cy, cz = pos[0] + size[0] * 0.5, pos[1], pos[2] + size[2] * 0.5
    th = math.radians(yaw_deg)
    ct, st = math.cos(th), math.sin(th)
    gx = s * (ct * -cx + st * -cz)
    gy = s * (-cy)
    gz = s * (-st * -cx + ct * -cz)
    basis = (s * ct, 0.0, -s * st, 0.0, s, 0.0, s * st, 0.0, s * ct)
    return basis, (ox + gx, gy, oz + gz)


# ---------------------------------------------------------------- vegetation
# variant suffix -> spec.  "" is the committed default (never regenerated).
VARIANTS = {
    "_b": {
        "kelp_bed": ("KelpBed", [
            ("kelp_a", 2.20, 0, 0.00, 0.00, "height"),
            ("kelp_b", 1.90, 60, 0.34, 0.20, "height"),
            ("kelp_a", 1.70, 150, -0.30, -0.16, "height"),
            ("kelp_b", 1.45, 240, 0.10, 0.34, "height"),
            ("kelp_a", 1.20, 20, 0.26, -0.24, "height"),
            ("kelp_b", 1.00, 190, -0.34, 0.22, "height"),
            ("kelp_a", 0.85, 100, -0.12, 0.00, "height"),
        ]),
        "sea_fan": ("SeaFan", [
            ("fan_b", 0.55, 0, 0.00, 0.00, "height"),
            ("fan_c", 0.40, 130, 0.26, 0.10, "height"),
            ("seafan_a", 0.34, 250, -0.20, 0.16, "height"),
        ]),
        "sponge": ("Sponge", [
            ("sponge_b", 0.60, 0, 0.00, 0.00, "footprint"),
            ("sponge_c", 0.45, 90, 0.22, 0.10, "footprint"),
            ("sponge_a", 0.50, 200, -0.20, 0.16, "footprint"),
        ]),
        "starfish": ("Starfish", [
            ("star_b", 0.75, 0, 0.00, 0.00, "footprint"),
        ]),
        "sea_urchin": ("SeaUrchin", [
            ("urchin_b", 0.42, 0, 0.00, 0.00, "height"),
            ("urchin_c", 0.32, 90, 0.28, 0.12, "height"),
            ("urchin_a", 0.36, 210, -0.22, 0.18, "height"),
        ]),
    },
    "_c": {
        "kelp_bed": ("KelpBed", [
            ("kelp_c", 2.60, 0, 0.00, 0.00, "height"),
            ("kelp_c", 2.20, 80, 0.30, 0.18, "height"),
            ("kelp_a", 1.80, 160, -0.30, -0.16, "height"),
            ("kelp_c", 1.50, 250, 0.10, 0.34, "height"),
            ("kelp_a", 1.25, 40, 0.26, -0.24, "height"),
            ("kelp_c", 1.05, 200, -0.32, 0.22, "height"),
            ("kelp_b", 0.90, 110, -0.12, 0.00, "height"),
        ]),
        "sea_fan": ("SeaFan", [
            ("fan_c", 0.50, 0, 0.00, 0.00, "height"),
            ("seafan_a", 0.42, 120, 0.26, 0.10, "height"),
            ("fan_b", 0.36, 240, -0.20, 0.16, "height"),
        ]),
        "sponge": ("Sponge", [
            ("sponge_c", 0.58, 0, 0.00, 0.00, "footprint"),
            ("sponge_a", 0.42, 90, 0.22, 0.10, "footprint"),
            ("sponge_b", 0.50, 200, -0.20, 0.16, "footprint"),
        ]),
        "starfish": ("Starfish", [
            ("star_c", 0.75, 0, 0.00, 0.00, "footprint"),
        ]),
        "sea_urchin": ("SeaUrchin", [
            ("urchin_c", 0.40, 0, 0.00, 0.00, "height"),
            ("urchin_a", 0.34, 90, 0.28, 0.12, "height"),
            ("urchin_b", 0.36, 210, -0.22, 0.18, "height"),
        ]),
    },
}

VEG_HEADER = (
    "; Seabed decor variant (per-level biome). Wraps real imported models from\n"
    "; assets/models/vegetation/ (see CREDITS.md). Base rests on y = 0; the level\n"
    "; instance supplies the final scale/yaw, exactly like the default scene.\n"
)

# ------------------------------------------------------------------- hazards
# name -> (model, yaw_deg, pitch_deg)
HAZARDS = {
    "hazard":        ("bag", 0.0, 0.0),
    "hazard_bottle": ("bottle", 0.0, 0.0),
    "hazard_can":    ("can", 0.0, 0.0),
    "hazard_hook":   ("hook", 0.0, 0.0),
    "hazard_net":    ("net", 0.0, 90.0),
}
HAZ_TARGET = 0.85
HAZ_MIN_BOX = 0.5

HAZ_HEADER = (
    "; Hazard: real ocean-litter model in the 'hazard' group. Model is centred on\n"
    "; the Area3D origin and the box collision hugs its scaled footprint.\n"
)


def emit(path, text):
    open(path, "w", encoding="utf-8").write(text)
    print("wrote", os.path.relpath(path, PROJ))


# vegetation variants (skip the "" default so level 1 is byte-identical)
for suffix, scenes in VARIANTS.items():
    for scene, (root, instances) in scenes.items():
        used = []
        for inst in instances:
            if inst[0] not in used:
                used.append(inst[0])
        lines = ["[gd_scene load_steps=%d format=3]\n\n" % (len(used) + 1), VEG_HEADER]
        eids = {}
        for i, m in enumerate(used):
            eid = "%d_%s" % (i + 1, m)
            eids[m] = eid
            lines.append('[ext_resource type="PackedScene" path="res://assets/models/vegetation/%s.glb" id="%s"]\n' % (m, eid))
        lines.append('\n[node name="%s" type="Node3D"]\n' % root)
        for i, inst in enumerate(instances):
            m, h, yaw, ox, oz = inst[0], inst[1], inst[2], inst[3], inst[4]
            mode = inst[5] if len(inst) > 5 else "height"
            basis, origin = veg_transform(m, h, yaw, ox, oz, mode)
            t = ", ".join([fmt(v) for v in (basis + origin)])
            lines.append('\n[node name="%s%d" parent="." instance=ExtResource("%s")]\n' % (m, i + 1, eids[m]))
            lines.append('transform = Transform3D(%s)\n' % t)
        emit(os.path.join(OBJ, scene + suffix + ".tscn"), "".join(lines))


def rot3(size, yaw, pitch):
    """AABB extents after R = Ry(yaw) * Rx(pitch) is applied to a box of `size`."""
    th, ph = math.radians(yaw), math.radians(pitch)
    cy_, sy_ = math.cos(th), math.sin(th)
    cp, sp = math.cos(ph), math.sin(ph)
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    lo, hi = [1e30] * 3, [-1e30] * 3
    for sx in (-hx, hx):
        for sy in (-hy, hy):
            for sz in (-hz, hz):
                x, y, z = sx, sy * cp - sz * sp, sy * sp + sz * cp
                x, z = x * cy_ + z * sy_, -x * sy_ + z * cy_
                lo = [min(lo[i], v) for i, v in enumerate((x, y, z))]
                hi = [max(hi[i], v) for i, v in enumerate((x, y, z))]
    return tuple(hi[i] - lo[i] for i in range(3))


def apply3(vec, yaw, pitch):
    th, ph = math.radians(yaw), math.radians(pitch)
    cy_, sy_ = math.cos(th), math.sin(th)
    cp, sp = math.cos(ph), math.sin(ph)
    x, y, z = vec
    y, z = y * cp - z * sp, y * sp + z * cp
    x, z = x * cy_ + z * sy_, -x * sy_ + z * cy_
    return (x, y, z)


# hazards
for scene, (model, yaw, pitch) in HAZARDS.items():
    pos, size = HAZ_MODELS[model]
    s = HAZ_TARGET / max(size)
    center = tuple(pos[i] + size[i] / 2 for i in range(3))
    o = tuple(-v for v in apply3(tuple(s * c for c in center), yaw, pitch))
    rx, px = math.radians(yaw), math.radians(pitch)
    cy_, sy_ = math.cos(rx), math.sin(rx)
    cp, sp = math.cos(px), math.sin(px)
    col0 = (s * cy_, 0.0, -s * sy_)
    col1 = (s * sp * sy_, s * cp, s * sp * cy_)
    col2 = (s * cp * sy_, -s * sp, s * cp * cy_)
    basis = (col0[0], col0[1], col0[2], col1[0], col1[1], col1[2],
             col2[0], col2[1], col2[2])
    rsize = rot3((size[0] * s, size[1] * s, size[2] * s), yaw, pitch)
    box = tuple(max(HAZ_MIN_BOX, rsize[i]) for i in range(3))
    t = ", ".join([fmt(v) for v in (basis + o)])
    uid_attr = ' uid="uid://bpvghtf2xcxcn"' if scene == "hazard" else ""
    lines = ["[gd_scene load_steps=4 format=3%s]\n\n" % uid_attr, HAZ_HEADER]
    lines.append('[ext_resource type="Script" path="res://scripts/hazard.gd" id="1_x"]\n')
    lines.append('[ext_resource type="PackedScene" path="res://assets/models/hazard/%s.glb" id="2_m"]\n' % model)
    lines.append('\n[sub_resource type="BoxShape3D" id="BoxShape3D_haz"]\n')
    lines.append("size = Vector3(%s, %s, %s)\n" % (fmt(box[0]), fmt(box[1]), fmt(box[2])))
    lines.append('\n[node name="Hazard" type="Area3D" groups=["hazard"]]\n')
    lines.append('script = ExtResource("1_x")\n')
    lines.append('\n[node name="Model" parent="." instance=ExtResource("2_m")]\n')
    lines.append("transform = Transform3D(%s)\n" % t)
    lines.append('\n[node name="CollisionShape3D" type="CollisionShape3D" parent="."]\n')
    lines.append('shape = SubResource("BoxShape3D_haz")\n')
    emit(os.path.join(OBJ, scene + ".tscn"), "".join(lines))
