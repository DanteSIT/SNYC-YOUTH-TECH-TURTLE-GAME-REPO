extends Control

signal back_pressed

var _preset_option: OptionButton
var _aa_option: OptionButton
var _scale_option: OptionButton
var _sharpen_slider: HSlider
var _shadows_option: OptionButton
var _ssao_check: CheckButton
var _ssr_check: CheckButton
var _fog_check: CheckButton
var _glow_check: CheckButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "Frame rate, vertical sync and graphics settings."
	hint.add_theme_font_size_override("font_size", 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	vbox.add_child(hint)

	var cap_row := HBoxContainer.new()
	cap_row.add_theme_constant_override("separation", 20)
	var cap_label := Label.new()
	cap_label.text = "Frame Rate"
	cap_label.custom_minimum_size = Vector2(260, 44)
	cap_label.add_theme_font_size_override("font_size", 22)
	cap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap_row.add_child(cap_label)
	var cap_option := OptionButton.new()
	cap_option.custom_minimum_size = Vector2(220, 44)
	for cap in DebugStats.get_fps_caps():
		cap_option.add_item("Unlimited" if cap == 0 else "%d FPS" % cap)
	cap_option.select(DebugStats.get_fps_cap_index())
	cap_option.item_selected.connect(_on_fps_cap_selected)
	cap_row.add_child(cap_option)
	vbox.add_child(cap_row)

	var vsync_row := HBoxContainer.new()
	vsync_row.add_theme_constant_override("separation", 20)
	var vsync_label := Label.new()
	vsync_label.text = "Vertical Sync"
	vsync_label.custom_minimum_size = Vector2(260, 44)
	vsync_label.add_theme_font_size_override("font_size", 22)
	vsync_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vsync_row.add_child(vsync_label)
	var vsync_check := CheckButton.new()
	vsync_check.custom_minimum_size = Vector2(220, 44)
	vsync_check.button_pressed = DebugStats.is_vsync_enabled()
	vsync_check.toggled.connect(_on_vsync_toggled)
	vsync_row.add_child(vsync_check)
	vbox.add_child(vsync_row)

	_build_graphics_section(vbox)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var back := Button.new()
	back.custom_minimum_size = Vector2(0, 44)
	back.text = "Back"
	back.pressed.connect(_on_back_pressed)
	vbox.add_child(back)


func _build_graphics_section(vbox: VBoxContainer) -> void:
	var section := Label.new()
	section.text = "GRAPHICS"
	section.add_theme_font_size_override("font_size", 24)
	section.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	vbox.add_child(section)

	var preset := _add_option_row(vbox, "Preset")
	for p in Graphics.get_presets():
		preset.add_item(p.name)
	preset.item_selected.connect(_on_preset_selected)
	_preset_option = preset

	var aa := _add_option_row(vbox, "Anti-Aliasing")
	for opt in Graphics.get_aa_options():
		aa.add_item(opt.name)
	aa.item_selected.connect(_on_aa_selected)
	_aa_option = aa

	var scale := _add_option_row(vbox, "Resolution Scale")
	for s in Graphics.get_scales():
		scale.add_item("%d%%" % int(round(s * 100.0)))
	scale.item_selected.connect(_on_scale_selected)
	_scale_option = scale

	var sharpen_row := _add_row(vbox, "Sharpen")
	var sharpen := HSlider.new()
	sharpen.custom_minimum_size = Vector2(220, 44)
	sharpen.min_value = 0.0
	sharpen.max_value = 100.0
	sharpen.step = 1.0
	sharpen.value_changed.connect(_on_sharpen_changed)
	sharpen_row.add_child(sharpen)
	_sharpen_slider = sharpen

	var shadows := _add_option_row(vbox, "Shadows")
	for s in Graphics.get_shadow_options():
		shadows.add_item(s.name)
	shadows.item_selected.connect(_on_shadows_selected)
	_shadows_option = shadows

	var ssao := _add_check_row(vbox, "Screen Space AO", Graphics.get_ssao())
	ssao.toggled.connect(_on_ssao_toggled)
	_ssao_check = ssao
	var ssr := _add_check_row(vbox, "Screen Space Reflections", Graphics.get_ssr())
	ssr.toggled.connect(_on_ssr_toggled)
	_ssr_check = ssr
	var fog := _add_check_row(vbox, "Fog & God Rays", Graphics.get_fog())
	fog.toggled.connect(_on_fog_toggled)
	_fog_check = fog
	var glow := _add_check_row(vbox, "Glow", Graphics.get_glow())
	glow.toggled.connect(_on_glow_toggled)
	_glow_check = glow

	_sync_controls()


func _add_row(vbox: VBoxContainer, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(260, 44)
	label.add_theme_font_size_override("font_size", 22)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	vbox.add_child(row)
	return row


func _add_option_row(vbox: VBoxContainer, label_text: String) -> OptionButton:
	var row := _add_row(vbox, label_text)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(220, 44)
	row.add_child(option)
	return option


func _add_check_row(vbox: VBoxContainer, label_text: String, pressed: bool) -> CheckButton:
	var row := _add_row(vbox, label_text)
	var check := CheckButton.new()
	check.custom_minimum_size = Vector2(220, 44)
	check.button_pressed = pressed
	row.add_child(check)
	return check


func _sync_controls() -> void:
	if _aa_option != null:
		_aa_option.select(Graphics.get_aa_index())
	if _scale_option != null:
		_scale_option.select(Graphics.get_scale_index())
	if _sharpen_slider != null:
		_sharpen_slider.set_value_no_signal(Graphics.get_sharpen() * 100.0)
	if _shadows_option != null:
		_shadows_option.select(Graphics.get_shadows_index())
	if _ssao_check != null:
		_ssao_check.set_pressed_no_signal(Graphics.get_ssao())
	if _ssr_check != null:
		_ssr_check.set_pressed_no_signal(Graphics.get_ssr())
	if _fog_check != null:
		_fog_check.set_pressed_no_signal(Graphics.get_fog())
	if _glow_check != null:
		_glow_check.set_pressed_no_signal(Graphics.get_glow())
	if _preset_option != null:
		_preset_option.select(Graphics.get_preset_index())


func _on_preset_selected(index: int) -> void:
	Graphics.set_preset(index)
	_sync_controls()


func _on_aa_selected(index: int) -> void:
	Graphics.set_aa(index)
	_sync_controls()


func _on_scale_selected(index: int) -> void:
	Graphics.set_scale(index)
	_sync_controls()


func _on_shadows_selected(index: int) -> void:
	Graphics.set_shadows(index)
	_sync_controls()


func _on_sharpen_changed(value: float) -> void:
	Graphics.set_sharpen(value / 100.0)
	_sync_controls()


func _on_ssao_toggled(pressed: bool) -> void:
	Graphics.set_ssao(pressed)
	_sync_controls()


func _on_ssr_toggled(pressed: bool) -> void:
	Graphics.set_ssr(pressed)
	_sync_controls()


func _on_fog_toggled(pressed: bool) -> void:
	Graphics.set_fog(pressed)
	_sync_controls()


func _on_glow_toggled(pressed: bool) -> void:
	Graphics.set_glow(pressed)
	_sync_controls()


func _on_fps_cap_selected(index: int) -> void:
	DebugStats.set_fps_cap_index(index)


func _on_vsync_toggled(pressed: bool) -> void:
	DebugStats.set_vsync_enabled(pressed)


func _on_back_pressed() -> void:
	back_pressed.emit()
