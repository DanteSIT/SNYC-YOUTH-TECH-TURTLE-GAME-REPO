# Turtle Godot — Orchestrator

Single source of truth for **architecture**, **game flow**, **coding standards**, and the
**level-generation pipeline**. This file is the "orchestrator": read it before changing any
system, and update it whenever a system changes.

> Runbooks & validation commands are at the bottom. The classic handoff notes live in
> `HANDOFF.md` (historical). This file supersedes it where they conflict.

## 1. Project facts

- **Engine:** Godot 4.7 stable — binary `/home/dante/Godot/Godot_v4.7-stable_linux.x86_64`
  (the `/usr/bin/godot` build rejects `--path`, do not use it for CLI work).
- **Renderer:** Forward+ (Vulkan). NVIDIA RTX 4060 Ti, `DISPLAY=:0` available for capture.
- **Structure:** corridor runner — turtle swims from `StartPipe` (+z) to `EndPipe` (−z).
  16 levels (`tutorial`, `level_1..15`, corridor ≈48 long), plus menu/level-select/settings/controls.
- **Hard rules (user directives):**
  1. Models must be **editable node-based scenes** (`.tscn` with `StaticBody3D`+meshes), never procedural at runtime.
  2. All project files stay under this repo. Scratch (`/tmp/opencode/`) is disposable.
  3. Never commit/push unless explicitly asked.

## 2. Autoload registry (single source of truth)

Declared in `project.godot [autoload]`. **Order matters** (earlier autoloads are created first).

| Autoload | File | Role |
|---|---|---|
| `InputSettings` | `scripts/core/input_settings.gd` | Key rebinding persistence |
| `PauseManager` | `scripts/core/pause_manager.gd` | ESC pauses in level; builds pause/controls/settings panels |
| `GameManager` | `scripts/core/game_manager.gd` | Game *state*: score, jellyfish, health, lives, unlocks, level list |
| `GameFlow` | `scripts/core/game_flow.gd` | **Director.** ALL scene transitions + UI path registry |
| `DebugStats` | `scripts/core/debug_stats.gd` | FPS cap, HUD debug, perf readouts |
| `Graphics` | `scripts/core/graphics_settings.gd` | Graphics settings presets + persistence |
| `NavCleanup` | `scripts/core/nav_cleanup.gd` | Strips stray navmesh data at scene load |
| `Audio` | `scripts/core/audio_manager.gd` | Music/ambience/SFX buses, per-scene music, settings (`user://audio.cfg`) |
| `SceneryBaker` | `scripts/core/scenery_baker.gd` | Bakes whitelisted static decor into MultiMesh at runtime |

**Rule:** if a feature's system (1) tracks its own data (2) is globally accessed (3) lives in
isolation → autoload. Everything else is a plain node/scene. UI, player, and enemies are **not** autoloads.

## 3. Game flow

```
splash ──▶ menu ──▶ level_select ──▶ level ──▶ level_complete ──▶ next level
              │                          │                        │
              ├── controls / settings ───┤                        └──▶ menu (after last)
              └── quit
```
Every arrow is a **`GameFlow` verb** (`to_menu`, `to_level_select`, `to_level_complete`,
`to_game_over`, `restart_current_level`, …). Game state transitions (`GameManager`) call
`GameFlow` — no script ever calls `get_tree().change_scene_*` directly except `GameFlow`.

## 4. Script map (responsibilities)

### `scripts/player/`
| Script | Role |
|---|---|
| `player_controller.gd` | Input → swim/boost physics, floor/ceiling, flow, damage routing |
| `player_animator.gd` | Swims `IDLE/SWIMMING/BOOST`, plays one-shot `EAT`/`HURT` from `animations/*.tres` |
| `player_visuals.gd` | Damage red-glow flash on the skin material |

Extra anims: `scenes/player/animations/eat.tres` (jaw chomp) and `hurt.tres` (jaw+head flinch),
registered into `Odysse/AnimationPlayer`'s default library at `_ready` (base clips come from the FBX import).

### `scripts/enemies/`
| Script | Role |
|---|---|
| `enemy.gd` | Basic chase enemy (Area/hitbox, `take_damage` on contact) |
| `chaser.gd` | Corridor-restricted chaser, activates on range, despawns behind player |
| `boss.gd` | Angler boss — behavior only (scene holds body/meshes) |
| `shark_boss.gd` | Shark boss — chase/spawn logic, imported `zshark.glb` body |
| `crab.gd` / `jellyfish.gd` | Ambient seabed / decorative swimmers |
| `fish.gd` / `fish_school.gd` | Ambient schooling fish |

### `scripts/world/` — environment & FX
`current.gd`, `caustics.gd`, `water_surface.gd`, `godrays.gd`, `motion_smear.gd`,
`cable.gd`, `debris.gd`, `sand_terrain.gd`, `depth_fog.gd` (per-level `DepthFog` node:
dives fog/background/ambient from the StartPipe to the EndPipe for a surface→depth gradient).

### `scripts/objects/` — interactive props
`collectable.gd` (jellyfish pickups: chomps via `PlayerAnimator.play_eat`), `hazard.gd`, `goal.gd`.

### `scripts/ui/`
`menu.gd`, `level_select.gd`, `hud.gd`, `splash.gd`, `game_over.gd`, `level_complete.gd`,
`settings.gd` + `controls.gd` (Control scripts, code-built — deferred conversion to `.tscn`),
`settings_screen.gd`, `controls_screen.gd`.

### `scripts/tutorial/`
`tutorial.gd` — staged tutorial prompts keyed to player position/input.

### `scripts/core/`
`game_flow.gd`, `game_manager.gd`, `audio_manager.gd`, `pause_manager.gd`, `input_settings.gd`,
`debug_stats.gd`, `graphics_settings.gd`, `resource_cache.gd`, `scenery_baker.gd`, `ocean_theme.gd`
(shared UI theme factory), `nav_cleanup.gd` (autoload — lives here, not `world/`).

## 5. Coding standards

- **Files:** `snake_case.gd`. **Classes:** prefer `const X := preload(...)` over `class_name`
  globals — class globals are not resolvable in headless runs until reimport (see `ocean_theme.gd`,
  `resource_cache.gd` fixes). Opt into `class_name` only for editor-first shared types.
- **Signals:** past-tense verbs (`jellyfish_changed`, `level_completed`), emitted from the node
  that owns the fact; consumers connect, never poll.
- **Typing:** always-typed locals/returns; `@export` for hand-tuned knobs; `@onready` for nodes;
  `@tool` only for editor-time scripts.
- **Scene org:** scenes are self-contained; external context enters via signals or parent-set
  `@export`. Corridor constants live in one place (player controller or `world/consts`).
- **Naming:** no magic path strings — use `GameFlow` UI consts / `GameManager.LEVELS`.

## 6. Level-generation pipeline

Levels are **generated text scenes** — editing them by hand is fine but every regeneration is
reproducible from this pipeline. The in-repo suite lives in `tools/`:

| Tool | What it does |
| --- | --- |
| `tools/bake_plants.gd` | Bakes ~11 editable plant scenes |
| `tools/bake_scenery.gd` | Bakes obstacle/platform/mountain scenes |
| `tools/gen_levels.py` | Generates the 16 baseline level scenes |
| `tools/migrate_scripts.py` | One-shot script-folder reorg (moves scripts into the §4 folders + rewrites `res://` refs + deletes legacy files); `--dry-run` to preview |
| `tools/pipeline/validate.sh` | Boots every level + splash; exits non-zero on any error |
| `tools/pipeline/run.sh` | Reproduces bake → gen → validate in order |

Run the whole thing with `bash tools/pipeline/run.sh`, or validate-only with
`bash tools/pipeline/validate.sh`.

> Historic note: post-generation placement passes (`place_scenery.py`, `place_creatures.py`,
> `rework_collectables.py`, `rework_sand.py`, `rotate_start_pipes.py`, `fix_dupes.py`) were
> scratch scripts kept in `/tmp/opencode/`, which is disposable by design. Their output is already
> baked into the committed level scenes. If level content must be regenerated, restore those passes
> under `tools/pipeline/` first and re-enable step 3 of `run.sh`.

**Rules that must never break:**
- Camera lane `x ∈ [1.5, 5.5]` stays clear of all scenery. Left walls `x=−3.35`, right walls
  `x=+5.2`, right-side mountains `x ≥ +9.5`. Backdrop mountains near pipes start ≥11 m past the pipe.
- `side * rng.uniform(...)` in Python only with a **positive** range, then multiply by sign.
- Bakers must preserve `StaticBody3D` + unit `BoxShape3D` in `obstacle.tscn`/`platform.tscn`.
- No `ConeMesh` in Godot 4.7 — cones are `CylinderMesh` with `top_radius=0.02`.
- Writers must emit `"".join(lines)` (never re-emit the original `text` blob).

## 7. Validation runbook

```bash
G=/home/dante/Godot/Godot_v4.7-stable_linux.x86_64
bash tools/pipeline/validate.sh          # 16 levels, menu, tutorial — all OK/FAIL
$G --headless --path . res://scenes/ui/splash.tscn --quit-after 20   # boot smoke test
# Screenshot: godot --script MUST use --path, or res:// returns null (black PNGs)
```

Screenshot capture scripts live in `tools/` (instantiate level → position camera → save PNG).

## 8. Performance contract

- Target: **< 100 draw calls / level after `SceneryBaker`** (MultiMesh baking of whitelisted
  static decor; ~3750 mesh draws → ~82 before).
- LOD threshold `rendering/mesh_lod/lod_change/threshold_pixels=1.5`; camera near/far 0.12/400.
- Ambient silt via `background_particles.tscn` at z=−16/0/16.