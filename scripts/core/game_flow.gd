extends Node
## GameFlow — the director / orchestrator autoload.
##
## Single authority for scene transitions and high-level game flow.
## All scene changes MUST route through this director so the UI, pause menu,
## level selection, and game state share one consistent transition path.
##
## Naming rule: every public method is a verb describing the *destination*
## (what the player is being taken to), not a raw scene swap.

## Central registry of UI scene paths. No code outside GameFlow (and the
## level list in GameManager) should reference scene files by path string.
const UI_MENU := "res://scenes/ui/menu.tscn"
const UI_LEVEL_SELECT := "res://scenes/ui/level_select.tscn"
const UI_CONTROLS := "res://scenes/ui/controls.tscn"
const UI_SETTINGS := "res://scenes/ui/settings.tscn"
const UI_GAME_OVER := "res://scenes/ui/game_over.tscn"
const UI_LEVEL_COMPLETE := "res://scenes/ui/level_complete.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Low-level transition primitives (internal building blocks).
func change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


func change_scene_deferred(path: String) -> void:
	get_tree().call_deferred("change_scene_to_file", path)


func change_scene_packed(packed: PackedScene) -> void:
	get_tree().change_scene_to_packed(packed)


## High-level flow verbs.
func to_menu() -> void:
	change_scene(UI_MENU)


func to_level_select() -> void:
	change_scene(UI_LEVEL_SELECT)


func to_controls() -> void:
	change_scene(UI_CONTROLS)


func to_settings() -> void:
	change_scene(UI_SETTINGS)


func to_game_over() -> void:
	change_scene_deferred(UI_GAME_OVER)


func to_level_complete() -> void:
	change_scene_deferred(UI_LEVEL_COMPLETE)


func restart_current_level() -> void:
	change_scene_deferred(GameManager.LEVELS[GameManager.current_level])