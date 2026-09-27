# Turtle Godot Project — Session Handoff & Commands

Use this file to continue working on the project from another device with opencode.

## Project

- **Project root:** `/home/dante-pc/Godot/turtle-godot-v-0.1/`
- **Godot binary:** `/home/dante-pc/Godot/Engine/Godot_v4.7.2-stable_linux_x86_64` (Godot 4.7 stable)
- **Renderer:** Forward+ (Vulkan), NVIDIA RTX 4060 Ti, DISPLAY=:0 available for screen capture

> NOTE: On a new device, you must first `git clone`/copy the project, install Godot 4.7, and adjust absolute paths below (Godot binary + any `/tmp/opencode` paths). Everything under `/tmp/opencode/` is scratch; treat it as disposable. The only durable artifact is the project itself in `turtle-godot-v-0.1/`.

## How to run & validate (run from project root)

```bash
G=/home/dante-pc/Godot/Engine/Godot_v4.7.2-stable_linux_x86_64
# Run any level scene (add --quit-after N frames to auto-close):
$G --headless res://scenes/levels/level_1.tscn --quit-after 8

# Validate ALL 16 levels for script/parse errors (should print OK x16):
for l in tutorial level_1 level_2 level_3 level_4 level_5 level_6 level_7 level_8 level_9 level_10 level_11 level_12 level_13 level_14 level_15; do \
  out=$($G --headless res://scenes/levels/$l.tscn --quit-after 8 2>&1); \
  errs=$(echo "$out" | grep -E "SCRIPT ERROR|Parse Error|Cannot open|Failed to load" | head -3); \
  [ -z "$errs" ] && echo "$l OK" || echo "$l FAIL"; done

# Headless (dummy renderer) is for logic checks; screen capture needs DISPLAY:
$G res://scene.tscn   # real window (use for screenshots via capture tool)
```

## Re-bake / regenerate object scenes

The object models are **generated** by GDScript tools, then saved as editable `.tscn` files. Re-run after editing the generator:

```bash
$G --headless --script res://tools/bake_scenery.gd   # obstacle, platform, rock_wall, mountain_blocky/round/pointy
```

Output lines are `BAKE <path> err=0`; all must be `err=0`. NOTE: the baker overwrites `obstacle.tscn`/`platform.tscn` — it MUST keep the `StaticBody3D` + `CollisionShape3D` (unit `BoxShape3D`) children, since the level instances give collision via their transform scale. Also **no `ConeMesh` in Godot 4.7** — use `CylinderMesh` with `top_radius = 0.02` for cone shapes. Mountains are 3 shape variants (`mountain_blocky.tscn` = stacked boxes/mesa, `mountain_round.tscn` = sphere hills, `mountain_pointy.tscn` = sharp cones) placed randomly.

## Scatter / placement scripts (Python, /tmp scratch — regenerate if lost)

- `/tmp/opencode/scatter.py` — adds plant instances + widens fish school defaults across all 16 levels.
- `/tmp/opencode/place_scenery.py` — adds rock wall + mountain instances across all 16 levels (3 mountain variants `o_mtnb`/`o_mtnr`/`o_mtnp`; mid ridge LEFT x=-4.5..-7 / RIGHT x=+9.5..12.5, far row x=±9.5-16.5, backdrop behind pipes starting ≥5m off-axis, one big axial cap mountain at ±22m).
- **CAMERA-LANE RULE (critical):** the turtle camera is on the RIGHT at x≈+3.58 (local `(3.576, 0.48, 0)`) and travels the corridor — keep ALL scenery out of the x∈[1.5, 5.5] band (check via node transforms after placing). Left walls x=-3.35 frame the view; right walls go to x=+5.2; right-side mountains must be x≥+9.5 (mountain half-width up to ~5 from the blocky base). **Gotcha:** `side * rng.uniform(-4.5, -7.0)` produces POSITIVE x — always use `side * rng.uniform(positive_range)`.
- `/tmp/opencode/place_creatures.py` — rescales/spreads crabs (per-crab varied scale 0.7–2.4, x=-2..2.2, y=0.15) + adds a 6-jellyfish string (`JellyS0-5`) along the swim path in every level. **BUG FIXED: script must write `"".join(lines)`, NOT the original `text`, or in-place line edits (crab rescale) get lost.**
- `/tmp/opencode/rotate_start_pipes.py` — rotates each level's `StartPipe` instance 180° about Y. Bubbles live at local z=+3.7 in `transition_pipe.tscn` (the far mouth from spawn); rotation moves them to the mouth the turtle emerges from. `EndPipe` is left as-is (its bubbles already face the turtle's entry). The pipe is axis-symmetric so the tunnel looks unchanged; game logic only reads pipe positions, not orientation.
- `/tmp/opencode/rework_sand.py` — swaps the level floor mesh material to `res://materials/sand.tres` (triplanar sand shader), removes the dead Terrain3D `SandFloor` node + `w_sand`/`w_sh` ext_resources, and lifts `ambient_light_energy` (0.22→0.34, 0.54→0.62).
- Both operate by inserting `[ext_resource ...]` lines before the first `[sub_resource]`/`[node]` and appending node blocks at EOF; also bump `[gd_scene load_steps=N]` by the number of new ext_resources.
- Rewrite pattern: parse existing ids, skip if present; emit `[node name="UniqueName" parent="." instance=ExtResource("id")]` + `transform`; use unique node-name prefixes (e.g. `RWall`, `Mtn`, `ExtraKelp`) to avoid collisions.
- **IMPORTANT (spawn-exit visibility):** keep a clear zone around each pipe — backdrop mountains behind pipes must start at pipe_z ± 5 or further and x=±4..15 (staggered both sides), so the pipe mouth is never covered when the player looks backward at the exit. Side mountains (x=±9.5..16.5) are fine along the full length.
- **PIPELINE ORDER (from pristine backup `/tmp/opencode/levels_today2`):** `place_scenery.py` → `place_creatures.py` → `rework_sand.py` → **`rotate_start_pipes.py`** (must run AFTER scenery/creatures, which restore/rewrite levels) → validate all 16 → screenshot check.
- **Sand floor**: do NOT use the Terrain3D `sand_floor.tscn`/`sand_terrain.gd` — it renders NOTHING (no storage configured) and was removed. The floor uses `materials/sand.tres` (shader `shaders/sand.gdshader`, texture `assets/textures/OIP (1) 1.jpg`) with warm tint + ripple normals + `self_glow`.
- Re-run sequence after changing anything:
  1. Restore `scenes/levels/` from a backup (see below).
  2. Re-run bake tools (if scenes changed).
  3. Re-run scatter/placement scripts.
  4. Validate all 16 levels (command above) + screenshot check.

## Level structure (all 16 levels)

- `scenes/levels/{tutorial, level_1..level_15}.tscn`
- Turtle at +z (tutorial z=17, others z=24), Goal at -z (tutorial -17, others -24); corridor length ~48 (tutorial ~34).
- `StartPipe`/`EndPipe`: instances of `scenes/objects/transition_pipe.tscn` (tunnel, radius 2).
- Gates/pillars = instances of `scenes/objects/obstacle.tscn`: `GateTop/GateBottom` (tutorial) or `Gate0`, `Gate1L/R`, `GoalPillarL/R` (others). Platforms = `scenes/objects/platform.tscn`. These instances use non-uniform scales (gates ~(5,0.55,0.55), pillars ~(0.4,3.2,0.4), platforms ~(1.6,0.3,2.6)).
- Every level has a `Reef` node with `res://assets/models/blender/ROCK_1.blend` rocks at x≈±2.6, plus `FishHome*` (single fish) and `SchoolA-D` (fish schools) nodes.
- Corridor: Floor 6 wide (x ±3), ceiling y=5.2, no walls — scenery (rock_wall at x=-3.35 and x=+5.2, mountains beyond x≈±9.5, never in the camera lane x∈[1.5,5.5]) hides the void.
- `.tscn` format: `[gd_scene load_steps=N format=3]` (level_1 has NO load_steps). No `[editable]` sections. Scenes referenced by path (no uid) so overwriting object `.tscn` files is safe.

## Camera (completed) — character_body_3d.gd

`scripts/character_body_3d.gd` computes `_tube_blend()` from level `StartPipe`/`EndPipe` nodes (TUBE_HALF_LEN=2.4, TUBE_RADIUS=2.0, TUBE_FALLOFF=1.0, smoothing 4.0) and lerps the camera rest origin between side `(3.58, 0.48, 0)` and tube `(0, 0.9, 1.8)`; always `look_at(global_position + (0,0.3,0))`. Camera is `Turtle/CharacterBody3D/Camera3D`.

## Menus / UI (current)

- Main menu `scenes/ui/menu.tscn` + `scripts/menu.gd` (3D underwater backdrop: corals, bubbles, rocks, animated turtle; PLAY/LEVELS/CONTROLES/SETTINGS/QUIT). Splash `scenes/ui/splash.tscn` is the boot scene, then menu.
- Level select `scenes/ui/level_select.tscn` + `scripts/level_select.gd`: grid of 16 level buttons (locked beyond `GameManager.levels_unlocked`), **God Mode button** (bottom-right) unlocks all levels for instant access to any level.
- Pause menu is built in code by `scripts/pause_manager.gd` (autoload, ESC in a level). It now applies the same ocean theme as the main menu (`_ocean_theme()` — StyleBoxFlat normal/hover/pressed/focus + font colors) to the pause/controls/settings panels, with a styled PAUSED title and a **Skip Level** button (`GameManager.next_level()`).
- Autoloads (`project.godot`): InputSettings, PauseManager, GameManager, DebugStats, Graphics.
- Game flow: `GameManager.start_level(i)` → level scene → goal → `complete_level()` → `level_complete.tscn` → `next_level()`. Game over → `game_over.tscn`.

## Backups / pitfalls

- Stale backups have bitten us before. Correct pristine pre-scenery backups: `/tmp/opencode/levels_today` and `/tmp/opencode/levels_today2`.
- Post-scenery (current complete) snapshot: `/tmp/opencode/levels_today3`, latest full state also in `/tmp/opencode/levels_current2` and `/tmp/opencode/proj_backup_camera`.
- `PIL` is available for screenshot pixel analysis (check `dark`/`rock` percentage per frame region).
- To screenshot from the turtle camera: instantiate a level in a temp Node scene, set `Turtle/CharacterBody3D.global_position`, make its `Camera3D` current, save the viewport after ~2.5s (`get_viewport().get_texture().get_image().save_png(...)`).

## User directives (hard constraints)

1. **Models must be editable node-based scenes** (StaticBody3D + mesh nodes saved as `.tscn`), NOT code/procedural at runtime.
2. Keep all project files under `/home/dante-pc/Godot/turtle-godot-v-0.1/` (git root). Scratch under `/tmp/opencode/`.
3. Never commit/push unless explicitly asked.

## Status (as of last session)

- 16 levels: vegetation enriched, fish swim, organic gate/platforms, sand floor (new triplanar sand shader, ambient lifted), rock walls + blocky/round/pointy mountains background, StartPipe bubbles rotated to the turtle's exit mouth, varied crab sizes (0.7–2.4) — all validate OK. Camera lane (x∈[1.5,5.5]) verified clear of scenery in all 16; right walls at x=+5.2, right mountains x≥+9.5. Spawn/goal pipe exits kept clear (backdrop ≥11m past each pipe).
- UI: level select has God Mode (unlock all levels); pause menu restyled to match main menu theme + Skip Level.
- Shell/navmesh FIXED: replaced the binary `Assets/seashell.blend` import with hand-authored `scenes/objects/shell.tscn`, but the instances triggered Godot "node vanished" recovery that REWROTE levels during `--import`/headless runs. Final resolution: **removed all `Shell0-3` instances + `o_shell` ext from all 16 levels** (levels are now stable under repeated runs; 0 navmesh/warning/parse errors). Leftover `scenes/objects/shellZ.tscn` deleted. `shell.tscn` remains as a usable seabed prop.
- Jellyfish (done): `scenes/objects/jellyfish.tscn` rebuilt as editable node scene (textured Dome from `Assets/jelly_head_blue.png`/`jelly_head_orange.png`, 7 tentacles, glow light) + new `scripts/jellyfish.gd` (random blue/orange variant, bob/sway, glow toggle). `/tmp/opencode/rework_creatures.py` places 4–7 jellyfish per level (tutorial 4, lvl1–5:5, 6–10:6, 11–15:7), scale 0.45–0.7, glow prob 0.3→0.85. Re-run it when regenerating levels (after place_creatures).
- Creature scale (done): FishHome*/School* instances randomized to 0.2–0.6 scale across all 16 levels.
- Bosses (done): Angler boss at levels 5 & 15; NEW **Shark boss at level 10** = `scenes/objects/shark_boss.tscn` + `scripts/shark_boss.gd` (no `_build`, area chase/spawn logic like boss.gd, collision `BoxShape3D(2.6,1.6,4.8)`), body = imported `Assets/models/zshark.glb` (Blender-exported from Unity `Turtle 2.0/Assets/Scenes/assests/Shark 1.1.blend.failed_import`, ~17k verts, faces −z like the angler). Verified loads clean.
- Unity assets imported: `Assets/models/zshark.glb`, textures `Assets/jelly_head_blue/orange.png`, `dolphin_tex.png`, `tuna_tex.png`, `manta_tex.png`, `swordfish_tex.png`, `coral_tex.png`, `sea_urchin_tex.png` (source `.failed_import` files ARE valid PNGs; blends are Blender 4.02). Dolphin/Tuna/Manta models exist but are very high-poly (24K–139K tris) — decimate before use.
- Audio: menu music = `assets/audio/menu sound turtle.mp3` wired into menu via the `Audio` autoload. Also copied `underwater music.mp3`, `tutorialmusic.mp3` for level/tutorial use. Fish eat `jellyfish-plastic-crunch.mp3` (collectable SFX); `Turtle-underwater-movement-66914.mp3` + `underwater-ambiencewav-14428.mp3` were unused and removed in the 2026 cleanup.
- Collectables (fixed): the Collect* nodes had been clobbered into a small band near spawn (z≈0.5–2) by a broken re-placement run. `/tmp/opencode/rework_collectables2.py` re-positions them: 1 above each `Platform*` node (y = py+0.9, in line of sight), rest spread evenly spawn→goal along the swim band (y alternates 0.9/1.7, x weave ±0.8), avoiding gates/hazards. Re-run it whenever levels are regenerated. Verified all 16 levels (0 errors) + screenshots `/tmp/opencode/coll_lvl1.png`, `coll_lvl2_plat.png`, `coll_lvl5_plat.png`.
- SCREENSHOT GOTCHA: `godot --script <file>` from the project dir does NOT resolve `res://` — you MUST pass `--path /home/dante-pc/Godot/turtle-godot-v-0.1` (or run with the level as main scene). Without it `load()` returns null and you save black images.
- Screenshots for review: `/tmp/opencode/jelly_lvl1.png`, `jelly_lvl5.png`, `jelly_lvl15.png`, `shark_lvl10.png`, `coll_lvl1.png`, `coll_lvl2_plat.png`, `coll_lvl5_plat.png`.
- Known pending: commit/push project to a remote so work can continue from another device (repo has no remote; user asked about this — not yet done).
- Next steps candidate (from `Turtle-Game-Idea-update-15/8/26.txt` in project root): turtle eat/damage animations + red damage glow + mouth; level-1 shallow light-blue water with depth gradient (water/fog color currently identical in all levels); more background objects; other enemies (hammerhead, barracuda, spear fishers — shark model now available).

## Session: audio system + chaser enemies + collectable replication

- **Audio buses + global music (done)**: new autoload `Audio` = `scripts/audio_manager.gd`. Creates `Music`/`Ambience`/`SFX` buses at runtime (project.godot has NO `[audio]` section). Owns a global music player routed to `Music`; per-scene track = `menu/splash/level_select/controls/settings/game_over/level_complete` → `menu sound turtle.mp3`, `tutorial` → `tutorialmusic.mp3`, levels → `underwater music.mp3`. Settings persisted to `user://audio.cfg` (`music_on`, `music_volume`, `ambience_on`, `ambience_volume`, `sfx_volume`). Hooks `node_added` to route any `AudioStreamPlayer` named `Ambience`/`Music` to the right bus automatically.
- **Routing (done)**: `bus = &"Ambience"` added to the `Ambience` player in all 16 levels + menu. Menu's old `Music` node REMOVED (AudioManager now plays menu music globally). Collectable `Crunch` and turtle `SwimSound` set to `SFX` bus in code.
- **Settings AUDIO section (done)**: `scripts/settings.gd` gained `_build_audio_section` — Music + Ambience toggles (CheckButton) and Music/Ambience/SFX volume sliders (HSlider 0–100), wired to the `Audio` autoload, synced via `_sync_audio_controls()`.
- **Chaser enemies (done)**: `scenes/objects/chaser.tscn` + `scripts/chaser.gd` — editable node scene (Area3D root, group `enemy`, SphereShape hitbox, red emissive fish body/tail/dorsal/eye meshes). Idles until player within 22 m, then chases at 3.6 m/s (lerped accel), faces its travel dir, body/tail sway anim, clamps to corridor (x ±3.5, y 0.3–4.8, z ±26), despawns when >26 m behind the player, deals 10 dmg on contact via `body.take_damage()`. Placed **2 per level** in levels 2–15 (none in level_1 or tutorial). Chaser0 ≈ (x ±1.7, y 1.3–2.2, z −3..−6), Chaser1 ≈ opposite side, z −13..−16.
- **Collectable replication (done)**: user hand-tuned level_1's collectables (15 nodes `Collect0–14`, no `CollectStart`, z −16.65..19.2, y mostly 1.1–1.36 with 3 high ~3.5–4.1 + 1 low ~0.27, x ~0.03–0.49) AND moved level_1 mountains out of the swim band (left mid mountains → x −6.9..−8.8, `MtnEnd1` → (8.73,1.5,1.4) scale 2.2). `/tmp/opencode/replicate_collectables.py` copies that layout to levels 2–15 with jitter/blocker clearance. ⚠ BUG LESSON: parsing floats with `re.findall` on the FULL transform line (incl. the word `Transform3D`) shifts indices by the "3" digit — always parse `m.group(1)` (inside parentheses) only. Re-run `replicate_collectables.py` after any regen.
- **Godot binary**: `godot`/`godot-runner` (/usr/bin, 4.6.3) was compiled WITHOUT `disable_path_overrides=no` → rejects `--path` AND can't load a project from CWD. The full binary is `/home/dante-pc/Godot/Engine/Godot_v4.7.2-stable_linux_x86_64` — use THAT for all `--path . --script` work. (Screenshot gotcha below still applies: always `--path .`.)
- **Validation**: all 18 scenes (menu, tutorial, levels 1–15) instantiate with 0 load failures; game boots headless clean with the new autoload (splash→menu); settings screen builds all audio controls (verified AUDIO/Music/Ambience/SFX labels present).
- Screenshots: `/tmp/opencode/chaser_lvl2.png`, `chaser_lvl5.png`, `chaser_lvl10.png`, `settings_audio.png` (also prior `jelly_lvl1/5/15.png`, `shark_lvl10.png`, `coll_lvl1.png`, `coll_lvl2_plat.png`, `coll_lvl5_plat.png`).
- Known pending (unchanged): git remote commit/push; turtle eat/damage animation + red glow + mouth; level-1 depth water gradient; other bosses/enemies.

## Session: full deep optimization 2026-09-06

- **Angler boss de-hardcoded (done)**: `scenes/objects/boss.tscn` is now a fully editable node tree (33 MeshInstance3D under a `Body` Node3D; materials/meshes as sub_resources; overall collision `BoxShape3D(6,3.6,2.8)`). `scripts/boss.gd` is **behavior-only** (no `_build()`). Numbers for stalk/pectoral-fin basis transforms were computed by `/tmp/opencode/compute_transforms.gd`. Shark boss already scene-based (`zshark.glb`) and was left untouched.
- **Sky/void hiding (done)**: every level env now has a `ProceduralSkyMaterial` + `Sky` (background_mode=Color, sky energy 1.0, `ambient_light_source=2`, `fog_sky_affect=0.5`, fog_density ×1.15) — replaces the flat `Color(0.045,0.3,0.44)` void everywhere. Camera near/far added to `scenes/player/turtle.tscn` (`near=0.12`, `far=400`).
- **Ambient silt GPUParticles3D (done)**: `scenes/objects/background_particles.tscn` instanced at 3 corridor points (z = −16, 0, 16, y=2.5) in all 16 levels (`AmbientSilt0-2`).
- **SceneryBaker autoload (done, VERIFIED)**: `scripts/scenery_baker.gd` (registered in project.godot `[autoload] SceneryBaker`) polls `get_tree().current_scene` in `_process()` — DO NOT rely on `SceneTree.node_added` for the level root in `--script` mode (it doesn't fire reliably); polling works. Bakes whitelisted static decor (13 plant/rock `.tscn` types) into `MultiMeshInstance3D` `BakedScenery*` groups, then frees the originals. Result: **~3750 mesh draw calls per level → ~82 MultiMesh draw calls** (all 16 levels, 0 leftovers). Group key = `(mesh instance id, canonical material instance id)`; `_canonical()` quantizes RGB to 1/16 so near-identical materials share a MultiMesh.
  - **CRITICAL MultiMesh gotcha (verified)**: assign `mm.mesh` FIRST, then `set_instance_transform(i, xf)`, then `custom_aabb`. Setting instances before mesh loses the data. `get_instance_transform()` read-back can transiently return identity in headless/dummy renderer but the GPU-rendered result is CORRECT (verified via screenshot pixel-diff: baked vs unbaked ≈6% diff, from material quantization only).
- **LOD / rendering project settings (done)**: `project.godot [rendering]` adds `rendering/mesh_lod/lod_change/threshold_pixels=1.5` (earlier LOD switches on distance for the imported `.blend` meshes, which import with `meshes/generate_lods=true`) and `default_clear_color=Color(0.02,0.25,0.36,1)` so anything un-covered by an env renders teal, not magenta.
- **⚠ CRITICAL LEVEL-FILE CORRUPTION FOUND & FIXED (the "obstacles in the way"/"horrible" issue)**: the level generator was writing **duplicate `transform` lines into node blocks** (the instanced sub-scene's internal mesh transforms were pasted in as extra top-level `transform =` props without `[node]` headers). Godot's text loader folds those into the PRECEDING node, and **last-wins**, so:
  - `MtnEnd1` in 12 levels ended up at `(1.4,1.5,1.4)` — a full-size end-cap mountain sitting dead-center in the corridor ~22 m in front of spawn.
  - All `Collect*` collectables in 13 levels collapsed into a 4 m cluster at z≈−1..3.2 instead of spanning the corridor.
  - Fix: `/tmp/opencode/fix_dupes.py` keeps only the FIRST `transform` property per node block (removed 104–118 dup lines in level 3–15, 57 in tutorial; levels 1/2/5 were already clean). Levels 1,2,5,11 additionally had `MtnEnd1` set to identity `(1.4,1.5,1.4)` — moved to z=46. NOW: all `MtnEnd0/1` at ±46 (tutorial ±39), collectables spread −16.7..21.5, 16 scenes validate with 0 fails. **Re-run `fix_dupes.py` after any level regeneration.**
- **Validation**: all 16 levels + menu/tutorial instantiate with 0 load failures; bake stats identical across levels (77–82 groups, 3096–3768 instances); obstacle audit shows no mid-lane mountains (0 hits at z=1.4).
