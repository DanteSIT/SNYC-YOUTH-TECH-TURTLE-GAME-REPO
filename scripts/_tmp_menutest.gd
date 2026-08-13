extends Node
var t := 0.0
var step := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
func _process(delta: float) -> void:
	t += delta
	if step == 0 and t > 1.0:
		step = 1
		PauseManager.toggle_pause()
		print("PAUSE paused=", get_tree().paused, " pause_vis=", PauseManager._pause_panel.visible)
	elif step == 1 and t > 1.5:
		step = 2
		PauseManager._on_settings_pressed()
		print("SETTINGS_OPEN settings_vis=", PauseManager._settings_panel.visible, " pause_vis=", PauseManager._pause_panel.visible)
	elif step == 2 and t > 2.0:
		step = 3
		PauseManager._on_settings_back_pressed()
		print("SETTINGS_BACK settings_vis=", PauseManager._settings_panel.visible, " pause_vis=", PauseManager._pause_panel.visible)
	elif step == 3 and t > 2.5:
		step = 4
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		PauseManager._input(ev)
		print("ESC_FROM_SETTINGS settings_vis=", PauseManager._settings_panel.visible, " pause_vis=", PauseManager._pause_panel.visible)
		PauseManager._on_settings_pressed()
		PauseManager._unpause()
		print("UNPAUSED settings_vis=", PauseManager._settings_panel.visible, " pause_vis=", PauseManager._pause_panel.visible)
		get_tree().quit()
