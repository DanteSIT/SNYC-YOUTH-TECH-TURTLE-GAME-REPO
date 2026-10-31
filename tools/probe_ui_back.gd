extends SceneTree
## Presses Escape on each menu screen and checks it lands back on the menu.
##
## The screens used to call the scene change first and set_input_as_handled()
## second. The scene change frees the screen, so get_viewport() was null and the
## game crashed on the way out.

const SCREENS := [
	["res://scenes/ui/settings.tscn", "Menu"],
	["res://scenes/ui/controls.tscn", "Menu"],
	["res://scenes/ui/level_select.tscn", "Menu"],
	["res://scenes/ui/game_over.tscn", "LevelSelect"],
	["res://scenes/ui/level_complete.tscn", "LevelSelect"],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures := 0
	for entry in SCREENS:
		var path: String = entry[0]
		var expected: String = entry[1]
		change_scene_to_file(path)
		for _i in 5:
			await process_frame

		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = true
		get_root().push_input(event)
		for _i in 5:
			await process_frame

		var now: String = String(current_scene.name) if current_scene else "null"
		var ok: bool = now == expected
		if not ok:
			failures += 1
		print("%-24s -> %-12s %s" % [path.get_file(), now, "ok" if ok else "FAIL (wanted %s)" % expected])

	print("UI BACK %s" % ("OK" if failures == 0 else "FAIL"))
	quit(1 if failures else 0)
