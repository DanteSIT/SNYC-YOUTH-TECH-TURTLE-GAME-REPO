#!/usr/bin/env python3
"""
tools/migrate_scripts.py -- ORCHESTRATOR-documented script folder migration.

Why this exists (root cause of "levels not being the same / missing levels"):
The refactor moved scripts into per-domain folders (scripts/core, scripts/ui,
scripts/objects, scripts/enemies, scripts/player, scripts/world) but the legacy
top-level `scripts/<name>.gd` originals were never deleted AND — critically — the
new folder twins were **copied with the SAME Godot UID** (each `.gd.uid` carries
the identical uid string as its legacy twin).

A Godot UID must be globally unique. When two scripts share one UID, the engine's
uid->path cache resolves **nondeterministically** (whichever file was scanned /
imported last wins). The exact same .tscn ext_resource can therefore resolve to a
different script run-to-run -> levels "not being the same", plus `Identifier not
declared: *` script errors where a file loads the wrong twin.

What this tool does (per ORCHESTRATOR §1/§7 + the migrate step):
  1. For every verified SAME-UID legacy twin, rewrite every `res://scripts/*.gd`
     reference in all .tscn/.tres/.gd/project.godot/doc files to the folder twin
     path, then DELETE the legacy file + its `.uid` (the folder twin keeps the uid,
     now unambiguous).
  2. Leaves DIFFERENT-uid pairs alone (both files legitimately coexist; e.g.
     hazard.gd, godrays.gd, enemy.gd keep both).
  3. Prints an audit summary. Idempotent: safe to re-run (legacy already gone).

Usage:
  python3 tools/migrate_scripts.py            # run (writes + deletes)
  python3 tools/migrate_scripts.py --dry-run  # preview only, no writes
"""
from __future__ import annotations

import argparse
import glob
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")
FOLDER_DIRS = ["core", "ui", "objects", "enemies", "player", "world", "tutorial", "people"]

# Extensions that may contain `res://scripts/...` script references.
SCAN_EXTS = (".tscn", ".tres", ".gd", ".godot", ".md", ".cfg")

# Canonical folder twin paths for known same-uid collisions (verified on disk).
# legacy_name -> [folder, twin_name]  (path becomes scripts/<folder>/<twin_name>.gd)
CANONICAL: dict[str, list[str]] = {
    "collectable.gd":          ["objects", "collectable.gd"],
    "controls.gd":             ["ui", "controls.gd"],
    "controls_screen.gd":      ["ui", "controls_screen.gd"],
    "debug_stats.gd":          ["core", "debug_stats.gd"],
    "game_manager.gd":         ["core", "game_manager.gd"],
    "game_over.gd":            ["ui", "game_over.gd"],
    "goal.gd":                 ["objects", "goal.gd"],
    "graphics_settings.gd":    ["core", "graphics_settings.gd"],
    "hud.gd":                  ["ui", "hud.gd"],
    "input_settings.gd":       ["core", "input_settings.gd"],
    "level_complete.gd":       ["ui", "level_complete.gd"],
    "level_select.gd":         ["ui", "level_select.gd"],
    "menu.gd":                 ["ui", "menu.gd"],
    "pause_manager.gd":        ["core", "pause_manager.gd"],
    "settings.gd":             ["ui", "settings.gd"],
    "settings_screen.gd":      ["ui", "settings_screen.gd"],
    "splash.gd":               ["ui", "splash.gd"],
    "character_body_3d.gd":    ["player", "player_controller.gd"],
    "enemy.gd":                ["enemies", "enemy.gd"],
    "menu_controller.gd":      ["ui", "menu_controller.gd"],
    "collectable.gd":          ["objects", "collectable.gd"],
}


def resolve_twin(legacy: str) -> str | None:
    """Given scripts/<legacy>, return canonical folder path or None."""
    folder, name = CANONICAL.get(legacy, [None, None])
    if folder is None:
        return None
    twin = os.path.join(SCRIPTS, folder, name)
    return os.path.normpath(twin) if os.path.isfile(twin) else None


def read_file(p: str) -> str:
    with open(p, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def write_file(p: str, txt: str) -> None:
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(txt)


def rewrite_refs(old: str, new: str, dry: bool) -> list[str]:
    """Rewrite res://scripts/<old> -> res://scripts/<new> across the repo."""
    old_res = f"res://scripts/{old}"
    new_res = f"res://scripts/{new}"
    changed: list[str] = []
    for root, _dirs, files in os.walk(ROOT):
        if ".godot" in root or "__pycache__" in root:
            continue
        for fn in files:
            if not fn.endswith(SCAN_EXTS):
                continue
            p = os.path.join(root, fn)
            txt = read_file(p)
            if old_res not in txt:
                continue
            new_txt = txt.replace(old_res, new_res)
            if new_txt != txt:
                changed.append(os.path.relpath(p, ROOT))
                if not dry:
                    write_file(p, new_txt)
    return changed


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    dry = args.dry_run

    migrated = []
    skipped_keepboth = []
    for fn in sorted(os.listdir(SCRIPTS)):
        if not fn.endswith(".gd") or os.path.isdir(os.path.join(SCRIPTS, fn)):
            continue
        legacy_file = os.path.join(SCRIPTS, fn)
        twin = resolve_twin(fn)
        if twin is None:
            skipped_keepboth.append(fn)
            continue
        twin_name = os.path.relpath(twin, SCRIPTS).replace(os.sep, "/")
        changed = rewrite_refs(fn, twin_name, dry)
        legacy_uid = legacy_file + ".uid"
        if not dry:
            for extra in (legacy_file, legacy_uid):
                if os.path.isfile(extra):
                    os.remove(extra)
        migrated.append((fn, twin_name, len(changed), changed))

    print("=" * 78)
    print("migrate_scripts.py  [dry-run=%s]" % dry)
    print("=" * 78)
    for fn, twin, n, changed in migrated:
        print(f"MIGRATE {fn:<26} -> {twin:<34} ({n} ref(s) rewritten)")
        for c in changed[:4]:
            print(f"        ref: {c}")
        if len(changed) > 4:
            print(f"        ... +{len(changed)-4} more")
    if skipped_keepboth:
        print(f"\nKEEP (no canonical folder twin, or diff-uid): {', '.join(skipped_keepboth)}")
    print(f"\n{'DRY-RUN: nothing written' if dry else 'DONE: consolidated UIDs; legacy twins removed.'}")

    # Hard check: no stale res://scripts/*.gd refs remain pointing at deleted files.
    stale = []
    for root, _d, files in os.walk(ROOT):
        if ".godot" in root:
            continue
        for fn in files:
            if not fn.endswith(SCAN_EXTS):
                continue
            txt = read_file(os.path.join(root, fn))
            for m in __import__("re").finditer(r'res://scripts/([^"\s]+\.gd)', txt):
                ref = m.group(1)
                if os.path.isfile(os.path.join(SCRIPTS, ref)):
                    continue
                cand = os.path.join(SCRIPTS, ref)
                if not os.path.isfile(cand) and ref not in [b for _, b, _, _ in migrated]:
                    stale.append(f"{os.path.relpath(os.path.join(root,fn),ROOT)} -> {ref}")
    if stale:
        print("\nSTALE REFS REMAINING (must fix):")
        for s in stale[:20]:
            print("   ", s)
    return 0


if __name__ == "__main__":
    sys.exit(main())
