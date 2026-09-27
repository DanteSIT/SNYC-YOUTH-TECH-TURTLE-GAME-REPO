#!/usr/bin/env bash
# Convenience wrapper: render the portrait rig from a set of angles.
# Usage: bash tools/shots.sh <outdir> [rig_scene]
set -euo pipefail
G="${GODOT:-/home/dante-pc/Godot/Engine/Godot_v4.7.2-stable_linux.x86_64}"
cd "$(dirname "${BASH_SOURCE[0]}")/.."
OUT="${1:-/tmp/opencode/shots/turtle}"
RIG="${2:-res://tools/portrait_rig.tscn}"
mkdir -p "$OUT"

shot () { # name spec...
  local name="$1"; shift
  timeout 240 "$G" --path . --script res://tools/shot.gd -- "$RIG" "$OUT/$name.png" "$*" 2>&1 \
    | grep -E "SHOT |Parse Error|SCRIPT ERROR" || echo "FAILED $name"
}

shot front "cam=0,1.0,6.5,look=0,0.9,0.0,w=1100,h=1100"
shot q34   "cam=3.0,1.6,4.8,look=0,0.9,0.2,w=1100,h=1100"
shot side  "cam=6.5,1.0,0.0,look=0,0.9,0.0,w=1100,h=1100"
shot head  "cam=0.9,1.05,3.1,look=0.15,0.95,1.9,w=900,h=900,fov=30"
echo "shots -> $OUT"
