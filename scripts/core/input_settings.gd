extends Node

const SAVE_PATH := "user://controls.cfg"
const ACTIONS := ["ui_left", "ui_right", "ui_accept", "shift"]


func _ready() -> void:
	load_bindings()


func load_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for action in ACTIONS:
		var keycode: int = cfg.get_value("bindings", action + "_keycode", -1)
		if keycode == -1:
			continue
		var physical: int = cfg.get_value("bindings", action + "_physical", 0)
		_apply_binding(action, keycode, physical)


func set_binding(action: String, keycode: int, physical: int) -> void:
	_apply_binding(action, keycode, physical)
	save_bindings()


func reset_to_defaults() -> void:
	InputMap.load_from_project_settings()
	var dir := DirAccess.open("user://")
	if dir:
		dir.remove("controls.cfg")


func save_bindings() -> void:
	var cfg := ConfigFile.new()
	for action in ACTIONS:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				cfg.set_value("bindings", action + "_keycode", ev.keycode)
				cfg.set_value("bindings", action + "_physical", ev.physical_keycode)
				break
	cfg.save(SAVE_PATH)


func _apply_binding(action: String, keycode: int, physical: int) -> void:
	var keep: Array[InputEvent] = []
	for ev in InputMap.action_get_events(action):
		if not ev is InputEventKey:
			keep.append(ev)
	InputMap.action_erase_events(action)
	for ev in keep:
		InputMap.action_add_event(action, ev)
	var key := InputEventKey.new()
	key.keycode = keycode as Key
	key.physical_keycode = physical as Key
	InputMap.action_add_event(action, key)
