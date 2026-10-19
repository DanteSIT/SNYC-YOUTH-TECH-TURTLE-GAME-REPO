# Hazard model credits

The `Hazard*` nodes used to be plain `BoxMesh` cubes. They now instance real
ocean-litter models (things that genuinely harm sea turtles), one scene per
model:

| Scene | Model file | Model | Author | Licence | Source |
|---|---|---|---|---|---|
| `scenes/objects/hazard.tscn` | `bag.glb` | Trash Bag | Quaternius | CC0 1.0 | https://poly.pizza/m/jYrMKg2Q7C |
| `scenes/objects/hazard_bottle.tscn` | `bottle.glb` | Bottle | Quaternius | CC0 1.0 | https://poly.pizza/m/FAHsHFXfTf |
| `scenes/objects/hazard_can.tscn` | `can.glb` | Soda Can | Kenney | CC0 1.0 | https://poly.pizza/m/KOLcdOATw6 |
| `scenes/objects/hazard_hook.tscn` | `hook.glb` | Fish hook | Poly by Google | CC-BY 3.0 | https://poly.pizza/m/3xxRFD2brcq |
| `scenes/objects/hazard_net.tscn` | `net.glb` | Fishing Net | J-Toastie | CC-BY 3.0 | https://poly.pizza/m/Z11I3AUBO9 |

All models were downloaded from <https://poly.pizza>. The **CC-BY 3.0** entries
require attribution — keep this file in the repo (and credit it in the game's
credits screen if one is added).

## How the scenes are built

Each scene is an `Area3D` in the `hazard` group driven by `scripts/hazard.gd`
(`damage`, optional `patrol_end`/`patrol_speed`). The model is centred on the
origin and scaled so its largest dimension is `0.85`; a `BoxShape3D` hugs the
scaled footprint for the damage volume. Levels keep their authored instance
transforms and each `Hazard*` node cycles through the five scenes, so a level
shows a variety of litter rather than five identical cubes. The scenes are
authored by `tools/gen_veg_hazard_scenes.py`; the per-level rotation is applied
by `tools/apply_level_biomes.py`.
