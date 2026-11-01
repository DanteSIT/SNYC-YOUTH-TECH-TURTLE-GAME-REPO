# Tools

Helper scripts for building and checking levels. Run Godot scripts from the
project root:

```bash
godot --headless --path . --script res://tools/<name>.gd -- [args]
```

## Level generation

- `gen_levels.py` — rebuilds all level scenes. Overwrites them, so commit first.
- `pipeline/relength.py` — sets the length of a level and moves its pipes, goal
  and spawn to match.
- `pipeline/clean_levels.py`, `theme_levels.py`, `place_debris.py` — level
  post-processing passes.
- `pipeline/validate.sh` — runs the checks below.

## Checks

- `probe_seabed.gd` — every level has a visible seabed.
- `probe_floor.gd` — the turtle lands on the floor instead of falling through.
- `probe_pipe_clearance.gd` — pipes are clear and traversable.
- `probe_buried.gd` — nothing is stuck inside the seabed.
- `probe_boss_facing.gd` — boss models face the player.
- `probe_outline.gd` — collectables and hazards have their glow outline.
- `probe_ui_back.gd` — Escape leaves each menu screen without crashing.
- `probe_roof.gd` — the soft roof keeps the turtle under the ceiling line.
- `probe_tutorial.gd` — tutorial steps wait for their action and reload at the saved step.
- `probe_progress.gd` — the campaign save round-trips and records only improve.
- `probe_level_select.gd` — level cards show cleared, next and locked states.
- `probe_menu.gd` — the menu shows Play or Continue to match saved progress.
- `probe_aabb.gd`, `inspect.gd` — print mesh bounds and node details.

## Screenshots

- `shot.gd` — loads a scene, frames a camera and saves a PNG. See the comment at
  the top for the full option list.
- `shots.sh` — renders the turtle portrait rig from several angles.

## One-off fixes

- `fix_spawn.py` — puts the turtle on the start pipe axis.
- `flatten_pipes.py` — clears sand around the start and end pipes.
- `fix_buried.py` — lifts collectables and hazards out of the sand.
- `ground_platforms.py` — drops platforms onto the seabed as rock piles.
- `remove_gates.py` — strips the gate obstacles from every level.
- `remove_ceiling.py` — strips the old hard ceiling from every level.
- `make_sand_textures.py`, `make_flotsam_textures.py` — generate textures.
- `diag_*.gd` — diagnostics kept from earlier rendering bugs.
