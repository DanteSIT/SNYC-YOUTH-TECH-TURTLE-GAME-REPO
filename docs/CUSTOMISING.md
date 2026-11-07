# Customising the game

This page answers one question: **“I want to change X — which file do I open?”**
You should not need to read the rest of the code to tune the game.

## The one tuning file

Most gameplay numbers live in **`scripts/core/tuning.gd`**. Open it, change a
number, save, then run the game again.

The file is grouped into small sections:

| Section | What it controls |
| --- | --- |
| `Tuning.Player` | Turtle speed, jump, boost, camera, soft roof, fall limit |
| `Tuning.Feel` | Screen shake and the short freeze after a hit |
| `Tuning.Collectable` | Jellyfish points, bob, spin and glow colours |
| `Tuning.Hazard` | Litter damage, patrol speed and the warning marker |
| `Tuning.Rules` | Max health, starting lives, stars and the jelly-star ratio |
| `Tuning.Assets` | File paths loaded from code (burst, sounds, outlines) |
| `Tuning.Levels` | The level list, in play order |

Common changes:

| I want to… | Change this |
| --- | --- |
| Make the turtle swim faster | `Tuning.Player.SPEED` |
| Make the jump higher | `Tuning.Player.JUMP_SPEED` |
| Make the boost faster | `Tuning.Player.BOOST_SPEED` |
| Change how high the soft roof is | `Tuning.Player.ROOF_HEIGHT` |
| Make litter hurt more | `Tuning.Hazard.DAMAGE` |
| Give the player more health | `Tuning.Rules.MAX_HEALTH` |
| Start with more lives | `Tuning.Rules.STARTING_LIVES` |
| Change jellyfish score | `Tuning.Collectable.POINTS` |
| Recolour every jellyfish | `Tuning.Collectable.DOME_COLOR` |
| Change how many jellyfish a star needs | `Tuning.Rules.JELLY_STAR_RATIO` |
| Add, remove or reorder levels | `Tuning.Levels.PATHS` |

These are `const` values, so a change applies on the **next run**. If the game
is already open, stop it and start again.

`scripts/core/game_manager.gd` keeps names like `GameManager.MAX_HEALTH` and
`GameManager.LEVELS`. Those now read from `Tuning`, so you do not need to edit
them. `GameManager` is still the place that owns the save file and the live
health/lives values.

## Swapping models and animations

Models and animations are **exported fields**, so you change them in the Godot
inspector instead of editing deep node paths.

### Turtle

Open **`scenes/player/turtle.tscn`** and select these nodes:

- **`CharacterBody3D/PlayerAnimator`**
  - `model_path` — the turtle model node
  - `animation_player_path` — where the `AnimationPlayer` sits inside that model
  - `idle_animation`, `swim_animation` — clip names
  - `eat_animation_name`, `hurt_animation_name` — one-shot clip names
  - `eat_animation`, `hurt_animation` — the clips added at startup
- **`CharacterBody3D/PlayerVisuals`**
  - `skin_path` — the mesh that flashes red on damage
  - `flash_color`, `flash_decay` — how the hit flash looks

If you drop in a different model, either rename its nodes to match these paths
or point the fields at the new nodes. `PlayerVisuals` falls back to the first
mesh it finds, so a missing `skin_path` will not break the scene.

### Jellyfish

Open **`scenes/objects/collectable.tscn`**. The `model_node` field names the
model node under the `Area3D` (currently `jeLLyfiSH`). Each instance can also
override `points`, `bob_amplitude`, `bob_speed`, `sway_amount` and `spin_speed`
in the inspector.

### Litter / hazards

Hazard scenes live in **`scenes/objects/hazard*.tscn`**. Each one exposes
`damage` and `patrol_speed`. The warning marker is built from `Tuning.Hazard`,
so its colour, size and pulse are changed in one place.

## Menu scenery

The menu background is a readable table at the top of
**`scripts/ui/menu.gd`**:

```gdscript
const BACKDROP: Array[Dictionary] = [
    {
        "scene": CORALS_SCENE, "name": "CoralsLeft",
        "position": Vector3(3.69, 2.39, -2.65),
        "rotation": Vector3(0, -118.57, 0),
        "scale": Vector3.ONE,
    },
    ...
]
```

- `position` is in metres.
- `rotation` is in degrees.
- Add a row to place another model; remove a row to clear it.

The hero turtle is placed with `HERO_POSITION` and `HERO_ROTATION` just below
the table.

## Tutorial text

The tutorial steps are a data table at the top of
**`scripts/tutorial/tutorial.gd`** (`STAGES`). Each row has:

- `z` — where the step starts in the level
- `msg` — the instruction shown to the player
- `done` — the message shown when the step is complete
- `cond` — what the player must do (`swim`, `vertical`, `collect`, `boost`, or
  `none` for an information-only step)
- `mode` and `target` — where the marker points

Change the text there; the rest of the tutorial follows along.

## Level list and progress

`Tuning.Levels.PATHS` is the play order. The level select, Continue button and
save file all use it. Adding a scene to the list is enough to make it appear.

Campaign progress is saved separately in `user://progress.cfg` by
`scripts/core/game_manager.gd`. You normally do not need to edit that file.

## Checking your changes

From the project root:

```bash
# Boot every level and fail on script/load errors
GODOT=/path/to/godot bash tools/pipeline/validate.sh

# Focused checks
godot --headless --path . --script res://tools/probe_tuning.gd
godot --headless --path . --script res://tools/probe_tutorial.gd
```

`tools/README.md` lists every probe and what it protects.

## Where things live

| Path | Purpose |
| --- | --- |
| `scripts/core/tuning.gd` | Gameplay numbers — start here |
| `scripts/core/game_manager.gd` | Health, lives, score and the save file |
| `scenes/player/turtle.tscn` | Player scene and exported model/animation slots |
| `scripts/ui/menu.gd` | Menu backdrop table and button styling |
| `scripts/ui/level_select.gd` | Level cards |
| `scripts/tutorial/tutorial.gd` | Tutorial step table |
| `scenes/levels/` | One scene per level |
| `scenes/objects/` | Collectable, hazard, goal and scenery scenes |
