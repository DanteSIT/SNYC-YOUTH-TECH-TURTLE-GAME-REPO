#!/usr/bin/env python3
"""
Generate the 16 levels for Turtle Odyssey -- a SIDE-SCROLLING turtle game.
Coordinate model (this is the important bit):
  * The turtle only ever moves in Z (horizontal on screen) and Y (vertical).
    Its X is locked, so the entire playfield is the plane x = 0.
  * z decreases as you advance; the camera sits off to +X looking at the turtle.
  * x < 0 is BACKGROUND (visible, behind the turtle). x > 0 is behind the camera.
  * Therefore: every gameplay element (ground, platforms, gates, hazards,
    collectables, currents) is authored on x = 0, and scenery is layered in the
    background so plants read in front of rocks instead of being swallowed.
Particles are used only for small ambience (bubbles, silt, marine snow, drift).
Fish are real model nodes that swim, never particles.
"""
import math
import os
import random
ROOT = "/home/dante/turtle-godot-v-0.1/scenes/levels"
KEN = "res://assets/models/kenney"
NATURE = KEN + "/nature"
PIRATE = KEN + "/pirate"
SURV = KEN + "/survival"
PLANE_X = 0.0          # the playfield plane
CEIL_Y = 4.6           # low enough that the roof reads in frame
GROUND_TOP_CLAMP = (-1.4, 1.8)
# ---------------------------------------------------------------- resources
_RES = {}
def reg(rid, rtype, path):
    _RES[rid] = (rtype, path)
    return rid
reg("1_turt", "PackedScene", "res://scenes/player/turtle.tscn")
reg("2_coll", "PackedScene", "res://scenes/objects/collectable.tscn")
reg("3_haz", "PackedScene", "res://scenes/objects/hazard.tscn")
reg("4_goal", "PackedScene", "res://scenes/objects/goal.tscn")
reg("5_obs", "PackedScene", "res://scenes/objects/obstacle.tscn")
reg("6_plat", "PackedScene", "res://scenes/objects/platform.tscn")
reg("7_cur", "PackedScene", "res://scenes/effects/current.tscn")
reg("o_seabed", "PackedScene", "res://scenes/objects/seabed.tscn")
reg("o_bdfar", "PackedScene", "res://scenes/effects/backdrop_far.tscn")
reg("o_bdnear", "PackedScene", "res://scenes/effects/backdrop_near.tscn")
reg("sky_tex", "Texture2D", "res://assets/generated/uw_backdrop_far.png")
reg("o_coral", "PackedScene", "res://assets/models/blender/table coral.blend")
reg("o_star", "PackedScene", "res://scenes/objects/starfish.tscn")
reg("o_urchin", "PackedScene", "res://scenes/objects/sea_urchin.tscn")
reg("o_sponge", "PackedScene", "res://scenes/objects/sponge.tscn")
reg("o_fan", "PackedScene", "res://scenes/objects/sea_fan.tscn")
reg("o_kelp", "PackedScene", "res://scenes/objects/kelp_bed.tscn")
reg("o_boss", "PackedScene", "res://scenes/objects/boss.tscn")
reg("o_sboss", "PackedScene", "res://scenes/objects/shark_boss.tscn")
reg("o_chaser", "PackedScene", "res://scenes/objects/chaser.tscn")
reg("p_pipe", "PackedScene", "res://scenes/objects/transition_pipe.tscn")
reg("w_ws", "PackedScene", "res://scenes/effects/water_surface.tscn")
reg("g_rays", "PackedScene", "res://scenes/effects/godrays.tscn")
reg("5_bub", "PackedScene", "res://scenes/effects/bubbles.tscn")
reg("o_dust", "PackedScene", "res://scenes/effects/sea_dust.tscn")
reg("o_silt", "PackedScene", "res://scenes/effects/sand_silt.tscn")
reg("e_ocn", "PackedScene", "res://scenes/effects/ocean_particles.tscn")
reg("e_bgp", "PackedScene", "res://scenes/effects/background_particles.tscn")
reg("o_jelly", "PackedScene", "res://scenes/objects/jellyfish.tscn")
reg("o_uw", "PackedScene", "res://scenes/effects/underwater_overlay.tscn")
reg("d_fog", "Script", "res://scripts/world/depth_fog.gd")
reg("a_fish", "Script", "res://scripts/world/ambient_fish.gd")
reg("t_tut", "Script", "res://scripts/tutorial/tutorial.gd")
ROCK_IDS = {
    "rock_largeA": reg("k_rlA", "PackedScene", NATURE + "/rock_largeA.glb"),
    "rock_largeC": reg("k_rlC", "PackedScene", NATURE + "/rock_largeC.glb"),
    "rock_largeE": reg("k_rlE", "PackedScene", NATURE + "/rock_largeE.glb"),
    "rock_largeF": reg("k_rlF", "PackedScene", NATURE + "/rock_largeF.glb"),
    "rock_smallA": reg("k_rsA", "PackedScene", NATURE + "/rock_smallA.glb"),
    "rock_smallC": reg("k_rsC", "PackedScene", NATURE + "/rock_smallC.glb"),
    "rock_tallA": reg("k_rtA", "PackedScene", NATURE + "/rock_tallA.glb"),
    "rock_tallD": reg("k_rtD", "PackedScene", NATURE + "/rock_tallD.glb"),
    "rock_smallFlatB": reg("k_rsF", "PackedScene", NATURE + "/rock_smallFlatB.glb"),
    "stone_largeA": reg("k_slA", "PackedScene", NATURE + "/stone_largeA.glb"),
    "stone_tallA": reg("k_stA", "PackedScene", NATURE + "/stone_tallA.glb"),
}
PLANT_IDS = {
    "plant_bush": reg("k_pb", "PackedScene", NATURE + "/plant_bush.glb"),
    "plant_bushDetailed": reg("k_pbd", "PackedScene", NATURE + "/plant_bushDetailed.glb"),
    "plant_bushLarge": reg("k_pbl", "PackedScene", NATURE + "/plant_bushLarge.glb"),
    "plant_flatTall": reg("k_pft", "PackedScene", NATURE + "/plant_flatTall.glb"),
    "grass_large": reg("k_gl", "PackedScene", NATURE + "/grass_large.glb"),
    "lily_large": reg("k_ll", "PackedScene", NATURE + "/lily_large.glb"),
    "hanging_moss": reg("k_hm", "PackedScene", NATURE + "/hanging_moss.glb"),
    "stump_round": reg("k_sr", "PackedScene", NATURE + "/stump_round.glb"),
    "mushroom_tan": reg("k_mt", "PackedScene", NATURE + "/mushroom_tan.glb"),
}
PALM_IDS = {
    "tree_palmShort": reg("k_ps", "PackedScene", NATURE + "/tree_palmShort.glb"),
    "tree_palmTall": reg("k_pt", "PackedScene", NATURE + "/tree_palmTall.glb"),
    "tree_palmBend": reg("k_pbn", "PackedScene", NATURE + "/tree_palmBend.glb"),
}
LOG_IDS = {
    "log": reg("k_lg", "PackedScene", NATURE + "/log.glb"),
    "log_large": reg("k_lgl", "PackedScene", NATURE + "/log_large.glb"),
}
DEBRIS_IDS = {
    "barrel": reg("k_barrel", "PackedScene", PIRATE + "/barrel.glb"),
    "crate": reg("k_crate", "PackedScene", PIRATE + "/crate.glb"),
    "bottle": reg("k_bottle", "PackedScene", PIRATE + "/bottle.glb"),
    "bottle-large": reg("k_bottlel", "PackedScene", PIRATE + "/bottle-large.glb"),
    "chest": reg("k_chest", "PackedScene", PIRATE + "/chest.glb"),
    "cannon": reg("k_cannon", "PackedScene", PIRATE + "/cannon.glb"),
    "box": reg("k_box", "PackedScene", SURV + "/box.glb"),
    "bucket": reg("k_bucket", "PackedScene", SURV + "/bucket.glb"),
    "metal-panel": reg("k_panel", "PackedScene", SURV + "/metal-panel.glb"),
}
FISH_IDS = {
    "fish": reg("k_fish", "PackedScene", SURV + "/fish.glb"),
    "fish-large": reg("k_fishl", "PackedScene", SURV + "/fish-large.glb"),
}
WRECK_ID = reg("k_wreck", "PackedScene", PIRATE + "/ship-wreck.glb")
# ---------------------------------------------------------------- environments
ENVS = {
    "shallow": """
background_mode = 2
sky = SubResource("bsky")
ambient_light_source = 2
ambient_light_color = Color(0.5, 0.85, 1.0, 1)
ambient_light_energy = 0.72
reflected_light_source = 3
tonemap_mode = 3
tonemap_exposure = 0.95
tonemap_white = 2.2
ssr_enabled = true
ssr_fade_in = 0.1
ssr_fade_out = 4.0
ssao_enabled = true
ssao_radius = 0.035
ssao_intensity = 0.5
glow_enabled = true
glow_intensity = 0.7
glow_bloom = 0.12
glow_hdr_threshold = 1.0
fog_enabled = true
fog_light_color = Color(0.44, 0.76, 0.92, 1)
fog_light_energy = 0.95
fog_sun_scatter = 0.5
fog_density = 0.0105
fog_aerial_perspective = 0.15
fog_sky_affect = 0.5
volumetric_fog_enabled = true
volumetric_fog_density = 0.004
volumetric_fog_albedo = Color(0.38, 0.62, 0.72, 1)
volumetric_fog_emission_energy = 0.18
""",
    "mid": """
background_mode = 2
sky = SubResource("bsky")
ambient_light_source = 2
ambient_light_color = Color(0.42, 0.78, 0.98, 1)
ambient_light_energy = 0.62
reflected_light_source = 3
tonemap_mode = 3
tonemap_exposure = 0.92
tonemap_white = 2.1
ssr_enabled = true
ssr_fade_in = 0.1
ssr_fade_out = 4.0
ssao_enabled = true
ssao_radius = 0.035
ssao_intensity = 0.5
glow_enabled = true
glow_intensity = 0.75
glow_bloom = 0.14
glow_hdr_threshold = 0.95
fog_enabled = true
fog_light_color = Color(0.36, 0.66, 0.88, 1)
fog_light_energy = 0.8
fog_sun_scatter = 0.42
fog_density = 0.0128
fog_aerial_perspective = 0.12
fog_sky_affect = 0.45
volumetric_fog_enabled = true
volumetric_fog_density = 0.0048
volumetric_fog_albedo = Color(0.32, 0.55, 0.68, 1)
volumetric_fog_emission_energy = 0.16
""",
    "deep": """
background_mode = 2
sky = SubResource("bsky")
ambient_light_source = 2
ambient_light_color = Color(0.3, 0.66, 0.92, 1)
ambient_light_energy = 0.64
reflected_light_source = 3
tonemap_mode = 3
tonemap_exposure = 0.92
tonemap_white = 2.0
ssr_enabled = true
ssr_fade_in = 0.1
ssr_fade_out = 4.0
ssao_enabled = true
ssao_radius = 0.04
ssao_intensity = 0.55
glow_enabled = true
glow_intensity = 0.85
glow_bloom = 0.16
glow_hdr_threshold = 0.9
fog_enabled = true
fog_light_color = Color(0.24, 0.52, 0.78, 1)
fog_light_energy = 0.62
fog_sun_scatter = 0.3
fog_density = 0.0155
fog_aerial_perspective = 0.1
fog_sky_affect = 0.4
volumetric_fog_enabled = true
volumetric_fog_density = 0.0058
volumetric_fog_albedo = Color(0.24, 0.45, 0.6, 1)
volumetric_fog_emission_energy = 0.14
""",
    "abyss": """
background_mode = 2
sky = SubResource("bsky")
ambient_light_source = 2
ambient_light_color = Color(0.2, 0.5, 0.82, 1)
ambient_light_energy = 0.74
reflected_light_source = 3
tonemap_mode = 3
tonemap_exposure = 1.0
tonemap_white = 1.9
ssr_enabled = true
ssr_fade_in = 0.1
ssr_fade_out = 4.0
ssao_enabled = true
ssao_radius = 0.045
ssao_intensity = 0.6
glow_enabled = true
glow_intensity = 1.0
glow_bloom = 0.2
glow_hdr_threshold = 0.85
fog_enabled = true
fog_light_color = Color(0.14, 0.36, 0.62, 1)
fog_light_energy = 0.5
fog_sun_scatter = 0.22
fog_density = 0.0185
fog_aerial_perspective = 0.08
fog_sky_affect = 0.35
volumetric_fog_enabled = true
volumetric_fog_density = 0.0068
volumetric_fog_albedo = Color(0.16, 0.34, 0.5, 1)
volumetric_fog_emission_energy = 0.12
""",
}
DEPTH = {
    "shallow": {
        "fog": ((0.42, 0.70, 0.88), (0.30, 0.58, 0.80)),
        "bg": ((0.20, 0.52, 0.62), (0.10, 0.38, 0.52)),
        "amb": ((0.46, 0.70, 0.88), (0.38, 0.62, 0.82)),
        "fog_energy": (0.95, 0.72),
        "fog_density": (0.0022, 0.0075),
        "vol_density": (0.0025, 0.0042),
        "overlay": (0.10, 0.45),
    },
    "mid": {
        "fog": ((0.30, 0.58, 0.80), (0.22, 0.46, 0.70)),
        "bg": ((0.10, 0.38, 0.52), (0.05, 0.26, 0.42)),
        "amb": ((0.38, 0.62, 0.82), (0.30, 0.52, 0.74)),
        "fog_energy": (0.80, 0.62),
        "fog_density": (0.005, 0.011),
        "vol_density": (0.0035, 0.0055),
        "overlay": (0.30, 0.62),
    },
    "deep": {
        "fog": ((0.22, 0.46, 0.70), (0.14, 0.34, 0.56)),
        "bg": ((0.05, 0.26, 0.42), (0.025, 0.16, 0.32)),
        "amb": ((0.36, 0.58, 0.80), (0.28, 0.50, 0.72)),
        "fog_energy": (0.68, 0.52),
        "fog_density": (0.0060, 0.0125),
        "vol_density": (0.004, 0.0065),
        "overlay": (0.45, 0.78),
    },
    "abyss": {
        "fog": ((0.14, 0.34, 0.56), (0.08, 0.22, 0.42)),
        "bg": ((0.025, 0.16, 0.32), (0.010, 0.08, 0.22)),
        "amb": ((0.28, 0.50, 0.72), (0.20, 0.40, 0.62)),
        "fog_energy": (0.54, 0.40),
        "fog_density": (0.0075, 0.0140),
        "vol_density": (0.005, 0.008),
        "overlay": (0.60, 0.92),
    },
}
def g(v):
    return ("%.4f" % v).rstrip("0").rstrip(".") or "0"
def tx(sx, sy, sz, x, y, z, ry=0.0):
    # NOTE: the Z scale MUST use sz. It previously reused sx, which silently
    # collapsed long objects -- the water surface became a 6x6 patch instead of
    # spanning the level, and every seabed segment was forced to 13 long.
    c = math.cos(math.radians(ry))
    s = math.sin(math.radians(ry))
    return "Transform3D(%s, 0, %s, 0, %s, 0, %s, 0, %s, %s, %s, %s)" % (
        g(c * sx), g(-s * sz), g(sy), g(s * sx), g(c * sz), g(x), g(y), g(z))
class Level:

    def __init__(self, name, length, seed, tier, light_energy, floor_tint, sand_caustic):
        self.name = name[:-5] if name.endswith(".tscn") else name
        self.L = length
        self.rng = random.Random(seed)
        self.tier = tier
        self.light_energy = light_energy
        self.floor_tint = floor_tint
        self.sand_caustic = sand_caustic
        self.nodes = []
        self.half = length / 2.0
        self.spawn_z = self.half - 6.0
        self.goal_z = -self.half + 6.0
        self.counters = {}
        self.segs = []
    # -- helpers ---------------------------------------------------------

    def nid(self, base):
        self.counters[base] = self.counters.get(base, 0) + 1
        return "%s%d" % (base, self.counters[base])

    def inst(self, name, rid, transform, parent=".", extra=""):
        self.nodes.append('[node name="%s" parent="%s" instance=ExtResource("%s")]\ntransform = %s\n%s'
                          % (name, parent, rid, transform, extra))

    def prop(self, rid, x, y, z, scale=1.0, ry=0.0, parent="Scenery", prefix="Prop", sq=1.0):
        self.nodes.append('[node name="%s" parent="%s" instance=ExtResource("%s")]\ntransform = %s\n'
                          % (self.nid(prefix), parent, rid, tx(scale, scale * sq, scale, x, y, z, ry)))

    def ground_at(self, z):
        """Height of the seabed top at a given z."""
        if not self.segs:
            return 0.0
        for (z0, z1, top) in self.segs:
            if z1 <= z <= z0:
                return top
        return self.segs[0][2] if z > self.segs[0][0] else self.segs[-1][2]

    def band(self, z):
        """The reachable vertical band at z: clear of the seabed, below the roof.
        Anything placed outside this is unreachable or gets cut off by the
        ceiling/roof rocks -- which is what was clipping the platforms."""
        lo = self.ground_at(z) + 0.5
        hi = CEIL_Y - 0.75          # keeps bobbing pickups clear of the roof rocks
        if hi < lo + 0.8:
            hi = lo + 0.8
        return lo, hi

    def clamp_y(self, y, z):
        lo, hi = self.band(z)
        return min(max(y, lo), hi)

    def collect(self, y, z, x=PLANE_X):
        # collectables live on the playfield plane (tiny jitter is cosmetic)
        x = x + self.rng.uniform(-0.12, 0.12)
        y = self.clamp_y(y, z)
        self.inst(self.nid("Collect"), "2_coll", tx(1, 1, 1, x, y, z))

    def hazard(self, y, z, model_rid, scale=1.0, damage=25, bob=0.0, bob_speed=1.4,
               patrol_z=0.0, patrol_speed=1.5, spin=0.0):
        name = self.nid("Hazard")
        extra = "model_scene = ExtResource(\"%s\")\nmodel_scale = %s\ndamage = %d\n" % (
            model_rid, g(scale), damage)
        if bob > 0.0:
            extra += "bob_amplitude = %s\nbob_speed = %s\n" % (g(bob), g(bob_speed))
        if patrol_z != 0.0:
            extra += "patrol_end = Vector3(0, 0, %s)\npatrol_speed = %s\n" % (g(patrol_z), g(patrol_speed))
        if spin > 0.0:
            extra += "start_spin = %s\n" % g(spin)
        # hazards sit on the playfield plane: dodge them vertically
        y = self.clamp_y(y, z)
        self.nodes.append('[node name="%s" parent="." instance=ExtResource("3_haz")]\ntransform = %s\n%s'
                          % (name, tx(1, 1, 1, PLANE_X, y, z), extra))
    # -- terrain ---------------------------------------------------------

    def build_terrain(self):
        """Segmented seabed: a walk in ground height gives the level real relief."""
        rng = self.rng
        z = self.spawn_z + 4.0
        top = 0.0
        while z > self.goal_z - 4.0:
            ln = rng.uniform(7.0, 15.0)
            z2 = max(z - ln, self.goal_z - 4.0)
            if z > self.spawn_z - 7.0 or z2 < self.goal_z + 7.0:
                top = 0.0                       # flat, fair start and finish
            else:
                top = min(max(top + rng.uniform(-1.7, 1.7), GROUND_TOP_CLAMP[0]),
                          GROUND_TOP_CLAMP[1])
            self.segs.append((z, z2, top))
            self.nodes.append(
                '[node name="%s" parent="Terrain" instance=ExtResource("o_seabed")]\n'
                'transform = %s\n'
                % (self.nid("Bed"),
                   tx(13.0, 6.0, (z - z2) + 0.5, -1.5, top - 3.0, (z + z2) * 0.5)))
            z = z2
    # -- scenery (background layers) -------------------------------------

    def build_backdrops(self):
        """Parallax backdrop bands far behind the playfield, sized to the
        visible band (~4 m tall) so texture resolution is used efficiently.
        Each band spans the full level length; a per-level UV offset stops
        neighbouring bands lining up."""
        band_h = 4.0
        band_y = 2.0
        z_center = (self.spawn_z + self.goal_z) * 0.5
        off = self.rng.uniform(0.0, 0.55)
        self.nodes.append(
            '[node name="%s" parent="Backdrops" instance=ExtResource("o_bdfar")]\n'
            'transform = %s\n'
            'shader_parameter/offset_x = %s\n'
            'shader_parameter/offset_y = %s\n'
            % (self.nid("BdFar"), tx(self.L + 10.0, band_h, 1.0, -36.0, band_y, z_center, 90.0),
               g(off), g(0.0)))
        self.nodes.append(
            '[node name="%s" parent="Backdrops" instance=ExtResource("o_bdnear")]\n'
            'transform = %s\n'
            'shader_parameter/offset_x = %s\n'
            'shader_parameter/offset_y = %s\n'
            % (self.nid("BdNear"), tx(self.L + 10.0, band_h, 1.0, -21.0, band_y + 0.6, z_center - 6.0, 90.0),
               g((off + 0.37) % 1.0), g(0.04)))

    def build_roof(self):
        """Rocky roof hanging off the ceiling so the channel reads as a tunnel."""
        rng = self.rng
        z = self.goal_z - 2.0
        while z < self.spawn_z + 2.0:
            for _ in range(2):
                if rng.random() < 0.22:
                    continue
                x = rng.uniform(-3.8, -1.4)
                key = rng.choice(["rock_largeA", "rock_largeC", "rock_largeF", "rock_smallFlatB"])
                self.prop(ROCK_IDS[key], x, CEIL_Y - rng.uniform(0.02, 0.3),
                          z + rng.uniform(-1.2, 1.2), scale=rng.uniform(1.4, 2.0),
                          ry=rng.uniform(0, 360), prefix="Roof", sq=0.55)
            z += rng.uniform(2.6, 4.4)

    def build_backdrop(self):
        """Far ridge: small distant rocks near the ceiling, for depth."""
        rng = self.rng
        z = self.goal_z - 6.0
        while z < self.spawn_z + 6.0:
            for _ in range(2):
                if rng.random() < 0.3:
                    continue
                x = rng.uniform(-14.0, -7.5)
                i = rng.randrange(24)
                y = CEIL_Y - rng.uniform(0.5, 1.7) - (i % 3) * 0.4
                key = rng.choice(["rock_tallA", "rock_tallD", "rock_largeC", "rock_largeE", "stone_largeA"])
                self.prop(ROCK_IDS[key], x, y, z + rng.uniform(-2.0, 2.0),
                          scale=rng.uniform(1.5, 3.0), ry=rng.uniform(0, 360), prefix="Back", sq=0.7)
            z += rng.uniform(4.0, 7.0)

    def build_midrocks(self):
        """Middle layer: boulders between the plant band and the far ridge."""
        rng = self.rng
        z = self.goal_z - 2.0
        while z < self.spawn_z + 2.0:
            if rng.random() < 0.35:
                z += rng.uniform(3.5, 7.0)
                continue
            x = rng.uniform(-5.6, -3.4)
            key = rng.choice(["rock_largeA", "rock_largeC", "rock_largeF", "rock_tallA", "stone_tallA"])
            self.prop(ROCK_IDS[key], x, self.ground_at(z) + rng.uniform(-0.3, 0.3), z,
                      scale=rng.uniform(2.0, 3.4), ry=rng.uniform(0, 360), prefix="Mid")
            z += rng.uniform(3.5, 7.0)

    def place_life(self, rid, model_halfw, s_range, z, gy, prefix, sq=1.0):
        """Place a background prop so its SCALED footprint never enters the
        turtle's lane. x is derived from the footprint, not guessed."""
        rng = self.rng
        s = rng.uniform(s_range[0], s_range[1])
        halfw = model_halfw * s
        x = -0.9 - halfw - rng.uniform(0.05, 0.35)
        self.prop(rid, x, gy, z, scale=s, ry=rng.uniform(0, 360), prefix=prefix, sq=sq)

    def build_seabed_life(self):
        """Front background band: plants/coral/small life sitting on the ground.
        Sizes and footprints use MEASURED model bounds (table coral is 2.0x5.2,
        sponge 2.0 cubed), so nothing reaches the turtle's lane."""
        rng = self.rng
        plant_keys = list(PLANT_IDS.keys())
        # (halfwidth_xz, min_scale, max_scale, prefix)
        LIFE = [
            (0.30, 3.0, 5.2, "Plant"),
            (0.52, 2.0, 3.0, "Palm"),
            (0.50, 1.6, 2.6, "Kelp"),
            (1.00, 0.40, 0.70, "Coral"),
            (0.50, 1.4, 2.2, "Fan"),
            (0.17, 2.0, 3.5, "Urchin"),
            (1.00, 0.50, 0.90, "Sponge"),
        ]
        z = self.goal_z - 1.0
        while z < self.spawn_z + 1.0:
            gy = self.ground_at(z)
            r = rng.random()
            if r < 0.36:
                self.place_life(PLANT_IDS[rng.choice(plant_keys)], 0.30, (3.0, 5.2), z, gy, "Plant")
            elif r < 0.50:
                self.place_life(PALM_IDS[rng.choice(list(PALM_IDS.keys()))], 0.52, (2.0, 3.0), z, gy, "Palm")
            else:
                idx = rng.randrange(2, len(LIFE))
                hw, smin, smax, prefix = LIFE[idx]
                rid = {"Kelp": "o_kelp", "Coral": "o_coral", "Fan": "o_fan",
                       "Urchin": "o_urchin", "Sponge": "o_sponge"}[prefix]
                self.place_life(rid, hw, (smin, smax), z, gy, prefix)
            z += rng.uniform(0.9, 1.8)
        # near band: smaller plants right beside the path (closest safe distance)
        z = self.goal_z
        while z < self.spawn_z:
            if rng.random() < 0.72:
                key = rng.choice(["plant_bush", "plant_bushLarge", "grass_large", "plant_flatTall", "lily_large"])
                self.place_life(PLANT_IDS[key], 0.20, (1.8, 3.0), z, self.ground_at(z), "Near")
            z += rng.uniform(1.5, 3.0)
        # starfish resting flat on the ground
        z = self.goal_z
        while z < self.spawn_z:
            if rng.random() < 0.6:
                self.place_life("o_star", 0.50, (1.0, 2.0), z, self.ground_at(z) + 0.05, "Star")
            z += rng.uniform(4.0, 8.0)
        # small rocks on the bed
        z = self.goal_z
        while z < self.spawn_z:
            if rng.random() < 0.5:
                self.place_life(ROCK_IDS[rng.choice(["rock_smallA", "rock_smallC", "rock_smallFlatB"])],
                                0.25, (1.2, 2.2), z, self.ground_at(z), "BedRock", sq=0.7)
            z += rng.uniform(3.0, 6.0)
        # moss hanging from the ceiling
        z = self.goal_z
        while z < self.spawn_z:
            if rng.random() < 0.45:
                self.prop(PLANT_IDS["hanging_moss"], rng.uniform(-3.2, -0.6),
                          CEIL_Y - rng.uniform(0.05, 0.4), z,
                          scale=rng.uniform(1.6, 2.8), ry=rng.uniform(0, 360), prefix="Moss")
            z += rng.uniform(4.0, 7.5)
    # -- gameplay (playfield plane) --------------------------------------

    def build_platforms(self, count):
        """Floating ledges for the turtle to land on, with a reward above."""
        rng = self.rng
        for i in range(count):
            t = (i + 0.5) / max(count, 1)
            z = self.spawn_z - 11.0 - t * ((self.spawn_z - 11.0) - (self.goal_z + 11.0))
            gy = self.ground_at(z)
            y = self.clamp_y(gy + rng.uniform(1.3, 2.6), z)
            self.inst(self.nid("Platform"), "6_plat",
                      tx(rng.uniform(1.6, 2.4), 0.32, rng.uniform(2.4, 3.4), PLANE_X, y, z))
            for k in range(rng.randint(2, 3)):
                self.collect(y + 0.85 + k * 0.2, z + rng.uniform(-1.0, 1.0))

    def build_gates(self, count):
        """Rock pillars that leave a gap: swim over / under them."""
        rng = self.rng
        span = (self.spawn_z - 9.0) - (self.goal_z + 9.0)
        if count <= 0:
            return
        step = span / count
        low_first = rng.random() < 0.5
        for i in range(count):
            z = self.spawn_z - 9.0 - step * i
            lo, hi = self.band(z)
            if (i % 2 == 0) == low_first:
                # low wall rising from the ground -> swim over it
                h = rng.uniform(0.7, 1.3)
                top = min(lo + h, hi - 0.9)          # always leave room to pass
                h = max(0.45, top - lo)
                y = lo + h * 0.5
                self.inst(self.nid("Gate"), "5_obs", tx(4.2, h, 0.7, PLANE_X, y, z))
            else:
                # hanging pillar -> swim under it
                h = min(rng.uniform(0.7, 1.3), max(0.45, (CEIL_Y - lo) - 1.4))
                bottom = max(lo + 0.9, CEIL_Y - h - rng.uniform(0.05, 0.4))
                y = min(CEIL_Y - h * 0.5 - 0.05, bottom + h * 0.5)
                self.inst(self.nid("Gate"), "5_obs", tx(4.2, h, 0.7, PLANE_X, y, z))
            # a small reward tucked just past the gap
            for k in range(rng.randint(1, 3)):
                self.collect(y + rng.uniform(-0.8, 0.8), z - 2.0 - k * 1.5)

    def build_hazards(self, count):
        """Debris on the playfield plane: forces a vertical dodge."""
        rng = self.rng
        span = (self.spawn_z - 12.0) - (self.goal_z + 12.0)
        if count <= 0:
            return
        step = span / count
        keys = ["barrel", "crate", "bottle", "bottle-large", "box", "bucket", "metal-panel"]
        for i in range(count):
            z = self.spawn_z - 12.0 - step * i + rng.uniform(-1.2, 1.2)
            gy = self.ground_at(z)
            rid = DEBRIS_IDS[rng.choice(keys)]
            scale = rng.uniform(1.1, 1.8)
            mode = rng.random()
            if mode < 0.4:
                self.hazard(gy + 0.45, z, rid, scale=scale)
            elif mode < 0.75:
                self.hazard(gy + rng.uniform(1.1, 2.4), z, rid, scale=scale,
                            bob=rng.uniform(0.3, 0.7), bob_speed=rng.uniform(1.0, 1.9),
                            spin=rng.uniform(0, 6.0))
            else:
                self.hazard(gy + rng.uniform(0.8, 1.8), z, rid, scale=scale,
                            patrol_z=rng.uniform(3.0, 6.0), patrol_speed=rng.uniform(1.0, 1.8))

    def build_currents(self, count):
        rng = self.rng
        for i in range(count):
            t = (i + 0.6) / (count + 0.2)
            z = self.spawn_z - 15.0 - t * ((self.spawn_z - 15.0) - (self.goal_z + 15.0))
            flow = rng.choice([-2.2, -1.8, 1.4, 1.8])
            name = self.nid("Current")
            self.nodes.append('[node name="%s" parent="." instance=ExtResource("7_cur")]\ntransform = %s\n'
                              % (name, tx(1, 1, 1, PLANE_X, self.clamp_y(self.ground_at(z) + 1.6, z), z)))
            self.nodes.append('[node name="Push" parent="%s" index="1"]\nflow = %s\n' % (name, g(flow)))

    def build_collectables(self, density=1.0):
        """Jellyfish along the playfield plane, in readable shapes."""
        rng = self.rng
        z = self.spawn_z - 6.0
        while z > self.goal_z + 6.0:
            gy = self.ground_at(z)
            pattern = rng.random()
            if pattern < 0.45:
                # arc over an obstacle
                n = rng.randint(4, 7)
                y0 = gy + rng.uniform(0.8, 1.4)
                amp = rng.uniform(0.6, 1.5)
                for i in range(n):
                    t = i / max(n - 1, 1)
                    self.collect(y0 + math.sin(t * math.pi) * amp, z - i * 1.7)
                z -= n * 1.7 + rng.uniform(3.5, 6.0)
            elif pattern < 0.75:
                # straight ribbon
                n = rng.randint(3, 6)
                y = gy + rng.choice([0.9, 1.3, 1.8])
                for i in range(n):
                    self.collect(y, z - i * 1.8)
                z -= n * 1.8 + rng.uniform(4.0, 7.0)
            else:
                # rising climb (rewards going up)
                n = rng.randint(3, 5)
                for i in range(n):
                    self.collect(gy + 0.8 + i * 0.75, z - i * 1.1)
                z -= rng.uniform(6.0, 9.5)
            z -= (1.05 - density) * rng.uniform(2.0, 5.0)
    # -- fauna -----------------------------------------------------------

    def build_fish(self):
        """Real fish models that swim. No particles, no MultiMesh schools."""
        rng = self.rng
        z = self.goal_z + 8.0
        while z < self.spawn_z - 8.0:
            if rng.random() < 0.8:
                n = rng.randint(3, 7)
                bx = rng.uniform(-4.0, -1.1)
                by = rng.uniform(0.9, 4.0)
                for _ in range(n):
                    rid = FISH_IDS["fish"] if rng.random() < 0.6 else FISH_IDS["fish-large"]
                    sc = rng.uniform(2.6, 4.6)
                    self.nodes.append(
                        '[node name="%s" parent="Fauna" instance=ExtResource("%s")]\n'
                        'transform = %s\nscript = ExtResource("a_fish")\n'
                        'speed = %s\nbob_amplitude = %s\nforward = %s\nspan = %s\nphase = %s\n'
                        'yaw_offset_deg = %s\n'
                        % (self.nid("Fish"), rid,
                           tx(sc, sc, sc, bx + rng.uniform(-0.9, 0.9),
                              by + rng.uniform(-0.7, 0.7), z + rng.uniform(-2.2, 2.2)),
                           g(rng.uniform(0.9, 1.9)), g(rng.uniform(0.15, 0.4)),
                           "-1" if rng.random() < 0.7 else "1", g(rng.uniform(6.0, 12.0)),
                           g(rng.uniform(0.0, 10.0)), g(270.0)))
            z += rng.uniform(7.0, 13.0)
        # a few drifting jellyfish for scale and light
        for i in range(4):
            bz = self.spawn_z - 10.0 - (self.spawn_z - self.goal_z - 20.0) * i / 4.0
            sc = rng.uniform(0.5, 0.8)
            self.inst(self.nid("Jelly"), "o_jelly",
                      tx(sc, sc, sc, rng.uniform(-3.0, -1.2), self.ground_at(bz) + rng.uniform(1.0, 2.6), bz),
                      parent="Fauna",
                      extra="glow = %s\n" % ("true" if rng.random() < 0.6 else "false"))
    # -- set pieces ------------------------------------------------------

    def build_wreck(self, z):
        gy = self.ground_at(z)
        self.prop(WRECK_ID, rng_uniform(self.rng, -3.0, -1.4), gy, z,
                  scale=self.rng.uniform(0.30, 0.42), ry=self.rng.uniform(0, 360), prefix="Wreck")
        for _ in range(4):
            key = self.rng.choice(["barrel", "crate", "bucket", "metal-panel", "box"])
            self.prop(DEBRIS_IDS[key], self.rng.uniform(-3.4, -1.2), gy,
                      z + self.rng.uniform(-4.0, 4.0), scale=self.rng.uniform(0.9, 1.6),
                      ry=self.rng.uniform(0, 360), prefix="WreckProp")

    def build_boss(self, kind):
        z = (self.spawn_z + self.goal_z) * 0.5
        rid = "o_sboss" if kind == "sboss" else "o_boss"
        self.inst("Boss", rid, tx(1, 1, 1, PLANE_X, self.clamp_y(self.ground_at(z) + 1.6, z), z))

    def build_chasers(self, count):
        rng = self.rng
        for i in range(count):
            t = (i + 0.7) / (count + 0.4)
            z = self.spawn_z - 18.0 - t * ((self.spawn_z - 18.0) - (self.goal_z + 18.0))
            self.inst(self.nid("Chaser"), "o_chaser",
                      tx(1, 1, 1, PLANE_X, self.clamp_y(self.ground_at(z) + rng.uniform(1.2, 2.4), z), z))
    # -- effects ---------------------------------------------------------

    def build_effects(self, bubbles, dust):
        L = self.L
        self.inst("GodRays", "g_rays", tx(1, 1, 1, -1.0, 9.5, 0), extra="level_length = %d\n" % L)
        self.inst("WaterSurface", "w_ws", tx(6, 1, L, -1.0, 9.2, 0))
        for i in range(bubbles):
            z = self.spawn_z - 6.0 - (self.spawn_z - self.goal_z - 12.0) * i / max(bubbles, 1)
            # never in the camera lane (x ~ +3.58) -- that put bubbles right on the lens
            self.inst(self.nid("Bubbles"), "5_bub", tx(1, 1, 1, -3.4 if i % 2 == 0 else -2.0, 2.0, z))
        for i in range(dust):
            z = self.spawn_z - 8.0 - (self.spawn_z - self.goal_z - 16.0) * i / max(dust, 1)
            self.inst(self.nid("SeaDust"), "o_dust", tx(1, 1, 1, -1.0, 2.4, z))
            self.inst(self.nid("Silt"), "o_silt", tx(1, 1, 1, -1.0, self.ground_at(z) + 0.4, z))
        for i in range(3):
            z = self.spawn_z - 6.0 - (self.spawn_z - self.goal_z - 12.0) * i / 3.0
            self.inst(self.nid("OceanParticles"), "e_ocn", tx(1, 1, 1, -1.0, 2.6, z))
        for i in range(3):
            z = self.spawn_z - 8.0 - (self.spawn_z - self.goal_z - 16.0) * i / 3.0
            self.inst(self.nid("BgParticles"), "e_bgp", tx(1, 1, 1, -1.0, 3.0, z))

    def build_pipes_and_goal(self):
        self.inst("StartPipe", "p_pipe", tx(-1, 1, -1, PLANE_X, 1.4, self.spawn_z + 2.6))
        self.inst("EndPipe", "p_pipe", tx(1, 1, 1, PLANE_X, 1.4, self.goal_z))
        self.inst("Goal", "4_goal", tx(1, 1, 1, PLANE_X, 1.5, self.goal_z))
        self.inst("GoalPillarL", "5_obs", tx(0.4, 3.2, 0.4, -1.2, 1.5, self.goal_z))
        self.inst("GoalPillarR", "5_obs", tx(0.4, 3.2, 0.4, 1.2, 1.5, self.goal_z))
    # -- emit ------------------------------------------------------------

    def emit(self):
        dep = DEPTH[self.tier]
        tup = lambda c: ", ".join(("%.3f" % x) for x in c) + ", 1"
        sub = []
        sub.append("""[sub_resource type="PanoramaSkyMaterial" id="bsky_mat"]
panorama = ExtResource("sky_tex")
energy_multiplier = 1.15
""")
        sub.append('[sub_resource type="Sky" id="bsky"]\nsky_material = SubResource("bsky_mat")\n')
        sub.append('[sub_resource type="Environment" id="env"]\n' + ENVS[self.tier])
        sub.append('[sub_resource type="BoxShape3D" id="ceiling_shape"]\nsize = Vector3(20, 0.2, %s)\n' % g(float(self.L)))
        ext = "\n".join('[ext_resource type="%s" path="%s" id="%s"]' % (t, p, i)
                        for i, (t, p) in _RES.items())
        header = "[gd_scene load_steps=%d format=3]\n\n%s\n" % (
            len(_RES) + len(sub) + 1, ext)
        head = []
        if self.name == "tutorial":
            head.append('[node name="%s" type="Node3D"]\nscript = ExtResource("t_tut")\n' % self.name)
        else:
            head.append('[node name="%s" type="Node3D"]\n' % self.name)
        head.append('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("env")\n')
        head.append("""[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(-0.9704294, -0.06041102, 0.23370345, 0.054571275, 0.888204, 0.4561973, -0.23513567, 0.45546085, -0.8586426, 0, 1.6496612, 0)
light_color = Color(0.96, 1, 1.03, 1)
light_energy = %s
light_indirect_energy = 1.2
light_volumetric_fog_energy = 0.8
light_angular_distance = 1.5
light_specular = 0.366
shadow_enabled = true
""" % g(self.light_energy))
        head.append("""[node name="Ceiling" type="StaticBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %s, 0)
[node name="CollisionShape3D" type="CollisionShape3D" parent="Ceiling"]
shape = SubResource("ceiling_shape")
[node name="Backdrops" type="Node3D" parent="."]
[node name="Terrain" type="Node3D" parent="."]
[node name="Scenery" type="Node3D" parent="."]
[node name="Fauna" type="Node3D" parent="."]
""" % g(CEIL_Y))
        tail = []
        tail.append('[node name="Turtle" parent="." instance=ExtResource("1_turt")]\ntransform = %s\n'
                    % tx(1, 1, 1, PLANE_X, 0.8, self.spawn_z))
        tail.append('[node name="UnderwaterOverlay" parent="." instance=ExtResource("o_uw")]\n')
        tail.append(
            '[node name="DepthFog" type="Node" parent="."]\nscript = ExtResource("d_fog")\n'
            'start_fog = Color(%s)\nend_fog = Color(%s)\nstart_bg = Color(%s)\nend_bg = Color(%s)\n'
            'start_ambient = Color(%s)\nend_ambient = Color(%s)\n'
            'start_fog_energy = %s\nend_fog_energy = %s\nstart_fog_density = %s\nend_fog_density = %s\n'
            'start_vol_density = %s\nend_vol_density = %s\nstart_overlay_depth = %s\nend_overlay_depth = %s\n'
            % (tup(dep["fog"][0]), tup(dep["fog"][1]), tup(dep["bg"][0]), tup(dep["bg"][1]),
               tup(dep["amb"][0]), tup(dep["amb"][1]),
               g(dep["fog_energy"][0]), g(dep["fog_energy"][1]),
               g(dep["fog_density"][0]), g(dep["fog_density"][1]),
               g(dep["vol_density"][0]), g(dep["vol_density"][1]),
               g(dep["overlay"][0]), g(dep["overlay"][1])))
        body = "".join(head) + "\n" + "\n".join(self.nodes) + "\n" + "".join(tail)
        return header + "\n" + "\n".join(sub) + "\n" + body
def rng_uniform(rng, a, b):
    return rng.uniform(a, b)
def build(cfg):
    name, length, seed, tier, light_energy, floor_tint, sand_caustic = cfg
    lv = Level(name, length, seed, tier, light_energy, floor_tint, sand_caustic)
    rng = lv.rng
    frac = (length - 70.0) / 160.0
    idx = int(name.split("_")[1].replace(".tscn", "")) if name.startswith("level_") else 0
    n_gates = max(2, int(round(2 + frac * 10)))
    n_haz = max(1, int(round(1 + frac * 8)))
    n_plat = max(2, int(round(2 + frac * 7)))
    n_cur = 1 if length < 120 else (2 if length < 190 else 3)
    n_reef = max(1, idx // 4)
    n_chase = 0 if idx < 3 else (1 if idx < 8 else 2)
    lv.build_terrain()
    lv.build_backdrops()
    lv.build_roof()
    lv.build_backdrop()
    lv.build_midrocks()
    lv.build_seabed_life()
    if length >= 130 and rng.random() < 0.8:
        lv.build_wreck(lv.goal_z + (lv.spawn_z - lv.goal_z) * rng.uniform(0.45, 0.7))
    lv.build_platforms(n_plat)
    lv.build_gates(n_gates)
    lv.build_hazards(n_haz)
    lv.build_currents(n_cur)
    lv.build_collectables(density=1.0 if length < 140 else 1.15)
    lv.build_chasers(n_chase)
    if idx in (5, 15):
        lv.build_boss("boss")
    elif idx == 10:
        lv.build_boss("sboss")
    lv.build_fish()
    lv.build_effects(bubbles=max(2, length // 50), dust=max(2, length // 45))
    lv.build_pipes_and_goal()
    return lv.emit()
CONFIGS = [
    ("tutorial.tscn", 66, 101, "shallow", 1.20, "0.82,0.74,0.54", "0.55,0.85,1.0"),
    ("level_1.tscn", 88, 1, "shallow", 1.16, "0.80,0.72,0.52", "0.55,0.85,1.0"),
    ("level_2.tscn", 100, 2, "shallow", 1.14, "0.82,0.74,0.55", "0.55,0.85,1.0"),
    ("level_3.tscn", 112, 3, "shallow", 1.10, "0.78,0.70,0.52", "0.54,0.84,1.0"),
    ("level_4.tscn", 124, 4, "mid", 1.06, "0.74,0.66,0.48", "0.5,0.8,0.98"),
    ("level_5.tscn", 136, 5, "mid", 1.04, "0.74,0.66,0.48", "0.5,0.8,0.98"),
    ("level_6.tscn", 148, 6, "mid", 1.00, "0.72,0.64,0.46", "0.5,0.8,0.98"),
    ("level_7.tscn", 158, 7, "mid", 0.98, "0.72,0.64,0.46", "0.5,0.8,0.98"),
    ("level_8.tscn", 168, 8, "deep", 0.94, "0.66,0.58,0.44", "0.45,0.75,0.95"),
    ("level_9.tscn", 178, 9, "deep", 0.92, "0.66,0.58,0.44", "0.45,0.75,0.95"),
    ("level_10.tscn", 188, 10, "deep", 0.90, "0.64,0.56,0.42", "0.45,0.75,0.95"),
    ("level_11.tscn", 198, 11, "deep", 0.88, "0.64,0.56,0.42", "0.45,0.75,0.95"),
    ("level_12.tscn", 208, 12, "abyss", 0.84, "0.58,0.52,0.40", "0.42,0.72,0.94"),
    ("level_13.tscn", 216, 13, "abyss", 0.82, "0.58,0.52,0.40", "0.42,0.72,0.94"),
    ("level_14.tscn", 224, 14, "abyss", 0.80, "0.56,0.50,0.38", "0.42,0.72,0.94"),
    ("level_15.tscn", 232, 15, "abyss", 0.78, "0.56,0.50,0.38", "0.40,0.70,0.92"),
]
os.makedirs(ROOT, exist_ok=True)
only = os.environ.get("ONLY_LEVEL")
for cfg in CONFIGS:
    if only and cfg[0] != only:
        continue
    text = build(cfg)
    with open(os.path.join(ROOT, cfg[0]), "w") as f:
        f.write(text)
    print("wrote %-16s L=%d tier=%s (%d lines)" % (cfg[0], cfg[1], cfg[3], text.count("\n")))