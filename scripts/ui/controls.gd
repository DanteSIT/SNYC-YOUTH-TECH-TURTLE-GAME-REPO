extends Control

signal back_pressed

const ACTIONS := [
	{"action": "ui_left", "label": "Move Left"},
	{"action": "ui_right", "label": "Move Right"},
	{"action": "ui_accept", "label": "Swim Up / Jump"},
	{"action": "shift", "label": "Boost"},
]

var capturing := false

var _capture_action := ""
var _capture_button: Button
var _row_buttons := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _input(event: InputEvent) -> void:
	if not capturing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			return
		_apply_binding(_capture_action, event.keycode, event.physical_keycode)
		get_viewport().set_input_as_handled()


func cancel_capture() -> void:
	if not capturing:
		return
	capturing = false
	_capture_button.text = _action_key_text(_capture_action)


func _apply_binding(action: String, keycode: int, physical: int) -> void:
	InputSettings.set_binding(action, keycode, physical)
	capturing = false
	_capture_button.text = _action_key_text(action)
	_capture_button.grab_focus()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "CONTROLES"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "Click a button, then press the key you want to bind."
	hint.add_theme_font_size_override("font_size", 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	vbox.add_child(hint)

	for entry in ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		var label := Label.new()
		label.text = entry.label
		label.custom_minimum_size = Vector2(260, 44)
		label.add_theme_font_size_override("font_size", 22)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 44)
		btn.text = _action_key_text(entry.action)
		btn.pressed.connect(_on_rebind_pressed.bind(entry.action, btn))
		row.add_child(btn)
		_row_buttons[entry.action] = btn
		vbox.add_child(row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var reset := Button.new()
	reset.custom_minimum_size = Vector2(0, 44)
	reset.text = "Reset to Defaults"
	reset.pressed.connect(_on_reset_pressed)
	vbox.add_child(reset)

	var back := Button.new()
	back.custom_minimum_size = Vector2(0, 44)
	back.text = "Back"
	back.pressed.connect(_on_back_pressed)
	vbox.add_child(back)


func _on_rebind_pressed(action: String, btn: Button) -> void:
	capturing = true
	_capture_action = action
	_capture_button = btn
	btn.text = "Press a key..."


func _on_reset_pressed() -> void:
	InputSettings.reset_to_defaults()
	for action in _row_buttons:
		_row_buttons[action].text = _action_key_text(action)


func _on_back_pressed() -> void:
	capturing = false
	back_pressed.emit()


func _action_key_text(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var keycode: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			return OS.get_keycode_string(keycode)
	return "-"
