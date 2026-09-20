#!/usr/bin/env bash
# validate.sh — orchestrator validation runbook.
# Boots every level + the splash scene headless and fails if any script/parse/load error appears.
# Usage: bash tools/pipeline/validate.sh   (set GODOT env var to override the binary)
set -u

G="${GODOT:-/home/dante/Godot/Godot_v4.7-stable_linux.x86_64}"
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "== Godot: $G"
echo "== Project: $PROJ"

FAILED=0

check() {
    local label="$1" scene="$2"
    local out
    out="$($G --headless --path "$PROJ" --quit-after 8 "$scene" 2>&1 \
        | grep -iE "SCRIPT ERROR|Parse Error|Cannot open|Failed to load|Nil|null instance|Invalid call|Invalid access" || true)"
    if [ -n "$out" ]; then
        echo "FAIL $label"
        echo "$out" | head -3
        FAILED=1
    else
        echo "OK   $label"
    fi
}

echo "== Splash boot smoke"
out="$($G --headless --path "$PROJ" --quit-after 20 res://scenes/ui/splash.tscn 2>&1 \
    | grep -iE "SCRIPT ERROR|Parse Error|Cannot open|Failed to load" || true)"
if [ -n "$out" ]; then echo "FAIL splash"; echo "$out" | head -3; FAILED=1; else echo "OK   splash"; fi

echo "== Level loop"
for l in tutorial level_1 level_2 level_3 level_4 level_5 level_6 level_7 level_8 level_9 \
         level_10 level_11 level_12 level_13 level_14 level_15; do
    check "$l" "res://scenes/levels/$l.tscn"
done

if [ "$FAILED" -eq 0 ]; then
    echo "ALL PASS"
else
    echo "FAILURES DETECTED"
    exit 1
fi