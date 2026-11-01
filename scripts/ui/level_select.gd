extends Control

## Level select as a board of progression cards. Each card shows the level name,
## whether it is cleared, the best time and the best jellyfish count. The first
## unlocked level that has not been cleared is highlighted so there is always an
## obvious next step.

const COLUMNS := 4
const CARD_SIZE := Vector2(280, 108)
const CARD_GAP := 14

const TEXT := Color(0.90, 0.98, 1.0, 1.0)
const MUTED := Color(0.62, 0.80, 0.90, 1.0)
const LOCKED := Color(0.45, 0.56, 0.64, 1.0)
const NEXT := Color(1.0, 0.84, 0.40, 1.0)
const CLEARED := Color(0.45, 0.95, 0.66, 1.0)


func _ready() -> void:
	_build_grid()
	_build_summary()
	$BackButton.pressed.connect(_on_back_pressed)
	_build_god_mode_button()


func _build_grid() -> void:
	var grid := get_node("Grid") as GridContainer
	for child in grid.get_children():
		child.queue_free()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", CARD_GAP)

	var next := _next_index()
	for i in GameManager.LEVELS.size():
		grid.add_child(_build_card(i, i == next))


func _build_summary() -> void:
	var cleared := 0
	for i in GameManager.LEVELS.size():
		if GameManager.is_level_completed(i):
			cleared += 1
	if not GameManager.has_progress():
		$Summary.text = "Start with the tutorial to unlock the reef."
	elif cleared >= GameManager.LEVELS.size():
		$Summary.text = "All %d levels cleared. Nice swimming!" % cleared
	else:
		$Summary.text = "%d of %d levels cleared  ·  Next: %s" % [
			cleared, GameManager.LEVELS.size(), _level_name(_next_index())]


## The first unlocked level that has not been cleared. Falls back to the furthest
## unlocked level once everything is done.
func _next_index() -> int:
	for i in GameManager.LEVELS.size():
		if i < GameManager.levels_unlocked and not GameManager.is_level_completed(i):
			return i
	return GameManager.continue_index()


func _level_name(index: int) -> String:
	return "Tutorial" if index == 0 else "Level %d" % index


func _build_card(index: int, is_next: bool) -> Button:
	var unlocked := index < GameManager.levels_unlocked
	var completed := GameManager.is_level_completed(index)

	var btn := Button.new()
	btn.custom_minimum_size = CARD_SIZE
	btn.disabled = not unlocked
	btn.focus_mode = Control.FOCUS_ALL if unlocked else Control.FOCUS_NONE
	btn.tooltip_text = "" if unlocked else "Clear %s first" % _level_name(index - 1)
	btn.pressed.connect(_on_level_pressed.bind(index))
	_apply_card_styles(btn, unlocked, completed, is_next)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(col)

	var title := Label.new()
	title.text = ("✓  " if completed else "") + _level_name(index).to_upper()
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", TEXT if unlocked else LOCKED)
	col.add_child(title)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 13)
	status.text = _status_text(unlocked, completed, is_next)
	status.add_theme_color_override("font_color",
		LOCKED if not unlocked else (NEXT if is_next else CLEARED))
	col.add_child(status)

	var meta := Label.new()
	meta.text = _meta_text(index, unlocked, completed)
	meta.add_theme_font_size_override("font_size", 13)
	meta.add_theme_color_override("font_color", MUTED if unlocked else LOCKED)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(meta)

	if completed:
		var best_stars := GameManager.best_stars_for_level(index)
		var stars := Label.new()
		stars.text = "%d / %d STARS" % [best_stars, GameManager.STARS]
		stars.add_theme_font_size_override("font_size", 12)
		stars.add_theme_color_override("font_color",
			NEXT if best_stars >= GameManager.STARS else MUTED)
		col.add_child(stars)

	return btn


func _status_text(unlocked: bool, completed: bool, is_next: bool) -> String:
	if not unlocked:
		return "LOCKED"
	if is_next:
		return "NEXT"
	if completed:
		return "CLEARED"
	return ""


func _meta_text(index: int, unlocked: bool, completed: bool) -> String:
	if not unlocked:
		return "Clear %s first" % _level_name(index - 1)

	var best := GameManager.best_time_for_level(index)
	var jelly := GameManager.best_jelly_for_level(index)
	var total := GameManager.jelly_total_for_level(index)

	if completed:
		var time := GameManager.format_time(best)
		if total > 0:
			return "BEST %s   ·   JELLY %d / %d" % [time, jelly, total]
		return "BEST %s" % time
	return "Not played yet"


func _apply_card_styles(btn: Button, unlocked: bool, completed: bool, is_next: bool) -> void:
	var bg := Color(0.04, 0.28, 0.40, 0.92)
	var border := Color(0.32, 0.72, 0.88, 0.55)
	var width := 2
	if not unlocked:
		bg = Color(0.03, 0.08, 0.13, 0.62)
		border = Color(0.25, 0.38, 0.48, 0.40)
	elif is_next:
		bg = Color(0.08, 0.34, 0.44, 0.96)
		border = Color(1.0, 0.82, 0.38, 0.95)
		width = 3
	elif completed:
		bg = Color(0.03, 0.25, 0.28, 0.92)
		border = Color(0.30, 0.80, 0.55, 0.60)

	btn.add_theme_stylebox_override("normal", _style(bg, border, width))
	btn.add_theme_stylebox_override("hover",
		_style(bg.lightened(0.08), border.lightened(0.15), width))
	btn.add_theme_stylebox_override("pressed", _style(bg.darkened(0.15), border, width))
	btn.add_theme_stylebox_override("focus",
		_style(bg.lightened(0.08), Color(0.85, 0.98, 1.0, 0.95), width))
	btn.add_theme_stylebox_override("disabled", _style(bg, border, width))


func _style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(14)
	style.set_border_width_all(width)
	style.border_color = border
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style


func _build_god_mode_button() -> void:
	var btn := Button.new()
	btn.text = "God Mode"
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = -220.0
	btn.offset_top = -70.0
	btn.offset_right = -20.0
	btn.offset_bottom = -30.0
	btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	btn.pressed.connect(_on_god_mode_pressed)
	add_child(btn)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Mark it handled first: the scene change below frees this node, and
		# get_viewport() is null afterwards.
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_level_pressed(index: int) -> void:
	GameManager.start_level(index)


func _on_back_pressed() -> void:
	GameFlow.to_menu()


func _on_god_mode_pressed() -> void:
	GameManager.unlock_all_levels()
	_build_grid()
	_build_summary()
