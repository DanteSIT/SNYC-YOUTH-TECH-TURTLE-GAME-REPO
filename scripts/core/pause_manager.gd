extends CanvasLayer

const OceanTheme := preload("res://scripts/core/ocean_theme.gd")

var _pause_panel: Control
var _controls_panel: Control
var _controls_ui: Control
var _settings_panel: Control
var _settings_ui: Control


func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_pause_panel()
	_build_controls_panel()
	_build_settings_panel()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _settings_panel.visible:
		_show_pause_panel()
		get_viewport().set_input_as_handled()
		return
	if _controls_panel.visible:
		if _controls_ui.capturing:
			_controls_ui.cancel_capture()
		else:
			_show_pause_panel()
		get_viewport().set_input_as_handled()
		return
	if _is_in_level():
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if get_tree().paused:
		_unpause()
	else:
		get_tree().paused = true
		_pause_panel.visible = true


func _unpause() -> void:
	get_tree().paused = false
	_pause_panel.visible = false
	_controls_panel.visible = false
	_settings_panel.visible = false


func _is_in_level() -> bool:
	var scene := get_tree().current_scene
	return scene != null and GameManager.LEVELS.has(scene.scene_file_path)


func _show_pause_panel() -> void:
	_controls_panel.visible = false
	_settings_panel.visible = false
	_pause_panel.visible = true


func _build_pause_panel() -> void:
	_pause_panel = Control.new()
	_pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	_pause_panel.theme = OceanTheme.build_button_theme()
	add_child(_pause_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.09, 0.18, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_panel.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_panel.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(320, 0)
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.72, 0.95, 1, 1))
	title.add_theme_color_override("font_shadow_color", Color(0, 0.1, 0.22, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_constant_override("shadow_outline_size", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	_add_button(vbox, "Resume", _on_resume_pressed)
	_add_button(vbox, "Restart", _on_restart_pressed)
	_add_button(vbox, "Skip Level", _on_skip_level_pressed)
	_add_button(vbox, "Controls", _on_controls_pressed)
	_add_button(vbox, "Settings", _on_settings_pressed)
	_add_button(vbox, "Main Menu", _on_main_menu_pressed)


func _add_button(parent: Node, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(320, 48)
	btn.text = text
	btn.pressed.connect(callback)
	parent.add_child(btn)


func _build_controls_panel() -> void:
	_controls_panel = Control.new()
	_controls_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_controls_panel.visible = false
	_controls_panel.theme = OceanTheme.build_button_theme()
	add_child(_controls_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.06, 0.12, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_controls_panel.add_child(bg)

	_controls_ui = preload("res://scripts/ui/controls.gd").new()
	_controls_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_controls_ui.back_pressed.connect(_on_controls_back_pressed)
	_controls_panel.add_child(_controls_ui)


func _build_settings_panel() -> void:
	_settings_panel = Control.new()
	_settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_panel.visible = false
	_settings_panel.theme = OceanTheme.build_button_theme()
	add_child(_settings_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.06, 0.12, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_panel.add_child(bg)

	_settings_ui = preload("res://scripts/ui/settings.gd").new()
	_settings_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_ui.back_pressed.connect(_on_settings_back_pressed)
	_settings_panel.add_child(_settings_ui)


func _ocean_theme() -> Theme:
	return OceanTheme.build_button_theme()


func _on_resume_pressed() -> void:
	_unpause()


func _on_restart_pressed() -> void:
	_unpause()
	GameFlow.restart_current_level()


func _on_skip_level_pressed() -> void:
	_unpause()
	GameManager.next_level()


func _on_controls_pressed() -> void:
	_pause_panel.visible = false
	_controls_panel.visible = true


func _on_settings_pressed() -> void:
	_pause_panel.visible = false
	_settings_panel.visible = true


func _on_main_menu_pressed() -> void:
	_unpause()
	GameFlow.to_menu()


func _on_controls_back_pressed() -> void:
	_show_pause_panel()


func _on_settings_back_pressed() -> void:
	_show_pause_panel()
