#!/usr/bin/env bash
# run.sh — reproduce the level-generation pipeline from source-of-truth inputs.
# Run from the repo root. Levels are generated text scenes; bake first, then gen, then fix, then validate.
# Usage: bash tools/pipeline/run.sh    (set GODOT env var to override the binary)
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
G="${GODOT:-/home/dante/Godot/Godot_v4.7-stable_linux.x86_64}"

echo "== 1/4 Bake editable object scenes (requires editor contexts; run on a machine with DISPLAY, or --headless if the plugin tolerates it)"
# "$G" --headless --path . --script res://tools/bake_plants.gd
# "$G" --headless --path . --script res://tools/bake_scenery.gd

echo "== 2/4 Generate baseline levels"
python3 tools/gen_levels.py

echo "== 3/4 Post-generation transforms"
# Historic placement passes (place_scenery / place_creatures / rework_* / rotate_start_pipes /
# fix_dupes) were scratch scripts kept out of the repo. Their output is already baked into the
# committed level scenes; re-run them here if they are ever restored under tools/pipeline/.

echo "== 4/4 Validate"
bash tools/pipeline/validate.sh