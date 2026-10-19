# Vegetation model credits

These `.glb` models replace the previous primitive-built seabed decor
(`kelp_bed.tscn`, `sea_fan.tscn`, `sponge.tscn`, `starfish.tscn`,
`sea_urchin.tscn` were built from box/quad/sphere/capsule meshes).

All models were downloaded from <https://poly.pizza>. The **CC-BY 3.0** entries
require attribution — keep this file in the repo (and credit it in the game's
credits screen if one is added).

| File | Model | Author | Licence | Source |
|---|---|---|---|---|
| `kelp_a.glb` | Kelp | Poly by Google | CC-BY 3.0 | https://poly.pizza/m/4cFllH6Iazk |
| `kelp_b.glb` | Seaweed | Laney XR Labs | CC-BY 3.0 | https://poly.pizza/m/461xlaa6SZW |
| `kelp_c.glb` | Seaweed | Mohabins | CC0 1.0 | https://poly.pizza/m/oYxUdpyc4u |
| `seafan_a.glb` | Anemone | Poly by Google | CC-BY 3.0 | https://poly.pizza/m/1FMGb52XdD- |
| `sponge_a.glb` | Sponge | Poly by Google | CC-BY 3.0 | https://poly.pizza/m/0ICnrmv06-S |
| `sponge_b.glb` | Sponge | Poly by Google | CC-BY 3.0 | https://poly.pizza/m/2RHCA0D2RJ2 |
| `starfish_a.glb` | Starfish | Poly by Google | CC-BY 3.0 | https://poly.pizza/m/6H-0K9IEr56 |
| `urchin_a.glb` | Sea Urchin | Poly by Google | CC-BY 3.0 | https://poly.pizza/m/f4iwEhEP3-d |
| `urchin_b.glb` | Sea Urchin | Quaternius | CC0 1.0 | https://poly.pizza/m/uYSDAQuNT9 |
| `fan_b.glb` | Sea anemone | Poly by Google | CC-BY 3.0 | https://poly.pizza/m/5mWGVL6VgMd |
| `fan_c.glb` | underwater_enviro_coral | God Appeasers | CC-BY 3.0 | https://poly.pizza/m/0CrDBiCnI5e |
| `sponge_c.glb` | Sponge | Poly by Google | CC-BY 3.0 | https://poly.pizza/m/9BIIMAjPXOJ |
| `star_b.glb` | Star | Poly by Google | CC-BY 3.0 | https://poly.pizza/m/0ddNZ3EsIhw |
| `star_c.glb` | Star | Quaternius | CC0 1.0 | https://poly.pizza/m/Tyau1aS2r0 |
| `urchin_c.glb` | Sea Urchin Open | Quaternius | CC0 1.0 | https://poly.pizza/m/LdYoJyw4pQ |

The `*_*.png` / `*.jpg` files next to each `.glb` are textures that Godot
extracts from the embedded glTF images during import; they are part of the
source and must stay beside their `.glb`.

## How the wrapper scenes use them

`scenes/objects/{kelp_bed,sea_fan,sponge,starfish,sea_urchin}.tscn` instance
these models and scale each one so the whole prop matches the footprint/height
of the primitive placeholder it replaced, with the base resting on `y = 0`.
The 16 levels reference those scenes by path and apply their own per-instance
scale/rotation, so no level files needed editing.

## Per-level biomes

Each of the five decor scenes also has `_b` / `_c` **biome variants**
(`kelp_bed_b.tscn`, `sea_fan_c.tscn`, …) that swap in different models from the
table above. Every level points its five vegetation `ext_resource`s at a
different combination (the `BIOME` table in `tools/apply_level_biomes.py`), so
the same 16 levels no longer share one identical plant mix.
`scenes/levels/tutorial.tscn` and `scenes/levels/level_1.tscn` keep the default
(`kelp_bed.tscn`, …) look. The variants are authored by
`tools/gen_veg_hazard_scenes.py`.
