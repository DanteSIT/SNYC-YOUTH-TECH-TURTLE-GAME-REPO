extends SceneTree
## Checks the menu reacts to campaign progress.
##
## Usage: godot --headless --path . --script res://tools/probe_menu.gd

const SCENE := "res://scenes/ui/menu.tscn"
const PROBE_PATH := "user://probe_menu.cfg"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gm: Node = get_root().get_node("GameManager")
	gm.progress_path = PROBE_PATH
	gm.reset_progress(false)

	var fresh := await _load()
	_expect("new game shows PLAY", _play_text(fresh) == "PLAY")
	_expect("controls label is spelled", _controls_text(fresh) == "CONTROLS")
	var play := fresh.get_node("Menu/PlayButton") as Button
	_expect("primary button has its own style", play.has_theme_stylebox_override("normal"))
	_expect("buttons get UI sound wiring", play.has_meta("ui_sound"))
	fresh.queue_free()
	await process_frame

	gm.levels_unlocked = 3
	var returning := await _load()
	_expect("returning player sees CONTINUE", _play_text(returning) == "CONTINUE")
	_expect("continue targets the next level", gm.continue_index() == 2)
	returning.queue_free()
	await process_frame

	gm.reset_progress(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_PATH))
	gm.progress_path = gm.SAVE_PATH
	print("MENU %s" % ("OK" if _failures == 0 else "FAIL"))
	quit(1 if _failures else 0)


func _load() -> Node:
	var packed: PackedScene = load(SCENE)
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	await process_frame
	await process_frame
	return world


func _play_text(menu: Node) -> String:
	return (menu.get_node("Menu/PlayButton") as Button).text


func _controls_text(menu: Node) -> String:
	return (menu.get_node("Menu/ControlsButton") as Button).text


func _expect(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %-38s %s" % [label, "ok" if ok else "FAIL"])
