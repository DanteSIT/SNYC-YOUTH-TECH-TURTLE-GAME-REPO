# _unused

Assets and scripts that the game no longer references, parked here instead of
being deleted so they stay available for reuse or replacement.

Nothing in this folder is loaded at runtime. It was confirmed by walking the
reference graph from `project.godot`'s main scene (`res://scenes/ui/splash.tscn`)
and all 9 autoloads — see the notes column below.

## Why these are unused

| File | Why |
|---|---|
| `assets/models/seashell.blend` (+ `.blend1`) | Superseded by a hand-authored `shell.tscn`, which itself was later removed from all 16 levels (see `docs/HANDOFF.md`). Shipping a huge baked navmesh (147k verts). |
| `assets/models/zshark_Image.png` | 250-byte blank placeholder from the shark import; the real shark texture is baked into `zshark.glb`. |
| `assets/textures/OIP (1) 1.jpg` | Old flat sand JPEG; replaced by `sand_albedo.png`/`sand_normal.png` from `tools/make_sand_textures.py`. |
| `Thumbnail.blend` (+ `.blend1`) | Blender source for the project thumbnail; not referenced at runtime. |
| `scripts/core/resource_cache.gd` | Static mesh/material cache helper with no remaining call sites. |

## Not moved on purpose

- `scenes/objects/pipe_collision.tres` — kept deliberately as the old pipe-bake
  backup; it has an in-file comment saying so.
- `assets/models/kenney/LICENSE_*.txt` — license text stays beside the kits.
- `tools/`, `docs/`, `screenshots/` — dev pipeline, documentation and
  gitignored deliverables, not runtime assets.

## Restoring something

Move the file back to the same relative path it used to live at (drop the
`_unused/` prefix), e.g.:

    git mv _unused/assets/models/seashell.blend assets/models/seashell.blend

Godot will re-import it on the next editor open.
