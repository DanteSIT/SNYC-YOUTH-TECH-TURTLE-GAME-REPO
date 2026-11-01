extends Control

## Results screen for a cleared level. Shows the three earned stars, the time,
## jellyfish and score, and offers the next level, a retry, or the level select.

const GOLD := Color(1.0, 0.84, 0.40, 1.0)
const MUTED := Color(0.62, 0.82, 0.92, 1.0)
const DIM := Color(0.42, 0.58, 0.68, 1.0)
const TEXT := Color(0.92, 0.98, 1.0, 1.0)


func _ready() -> void:
	var level := GameManager.current_level
	$Title.text = "Tutorial Complete!" if level == 0 else "Level %d Complete!" % level
	$StarRow.set_stars(GameManager.last_stars)
	_show_hints()
	_show_stats()
	_show_best()

	$Buttons/NextButton.pressed.connect(_on_next_pressed)
	$Buttons/RetryButton.pressed.connect(_on_retry_pressed)
	$Buttons/MenuButton.pressed.connect(_on_menu_pressed)
	$Buttons/NextButton.text = "MAIN MENU" if level + 1 >= GameManager.LEVELS.size() \
		else "NEXT LEVEL"
	_style_buttons()
	$Buttons/NextButton.grab_focus()


func _show_hints() -> void:
	_set_hint($Hints/FinishHint, "Finish", true)
	_set_hint($Hints/JellyHint, "80% jelly", GameManager.earned_jelly_star())
	_set_hint($Hints/DamageHint, "No damage", GameManager.earned_no_damage_star())


func _set_hint(label: Label, text: String, earned: bool) -> void:
	label.text = ("✓ " if earned else "· ") + text
	label.add_theme_color_override("font_color", GOLD if earned else DIM)


func _show_stats() -> void:
	$StatsLabel.text = "Time %s      Jelly %d / %d      Score %d" % [
		GameManager.format_time(GameManager.level_time),
		GameManager.jellyfish,
		GameManager.level_jellyfish_total,
		GameManager.score,
	]


## A first clear and a new record get their own callout; otherwise the screen
## just reminds the player what the level's best time is.
func _show_best() -> void:
	if GameManager.last_previous_best <= 0.0:
		$BestLabel.text = "FIRST CLEAR"
		$BestLabel.add_theme_color_override("font_color", GOLD)
	elif GameManager.last_new_best:
		$BestLabel.text = "NEW BEST TIME  ·  was %s" % GameManager.format_time(
			GameManager.last_previous_best)
		$BestLabel.add_theme_color_override("font_color", GOLD)
	else:
		$BestLabel.text = "BEST %s" % GameManager.format_time(
			GameManager.best_time_for_level(GameManager.current_level))
		$BestLabel.add_theme_color_override("font_color", MUTED)


func _style_buttons() -> void:
	var next := $Buttons/NextButton as Button
	next.add_theme_stylebox_override("normal", _style(
		Color(0.05, 0.52, 0.58, 0.98), GOLD, 3, 14))
	next.add_theme_stylebox_override("hover", _style(
		Color(0.08, 0.62, 0.68, 1.0), Color(1.0, 0.90, 0.56, 1.0), 3, 18))
	next.add_theme_stylebox_override("pressed", _style(
		Color(0.03, 0.38, 0.46, 1.0), GOLD, 3, 6))
	next.add_theme_stylebox_override("focus", _style(
		Color(0.08, 0.62, 0.68, 0.9), Color(1.0, 0.96, 0.82, 1.0), 3, 12))
	next.add_theme_font_size_override("font_size", 24)
	next.add_theme_color_override("font_color", Color(1.0, 0.98, 0.9, 1.0))

	for button in [$Buttons/RetryButton, $Buttons/MenuButton]:
		var quiet := button as Button
		quiet.add_theme_stylebox_override("normal", _style(
			Color(0.05, 0.24, 0.32, 0.92), Color(0.32, 0.70, 0.86, 0.55), 2, 8))
		quiet.add_theme_stylebox_override("hover", _style(
			Color(0.08, 0.34, 0.42, 0.96), Color(0.48, 0.84, 0.95, 0.85), 2, 12))
		quiet.add_theme_stylebox_override("pressed", _style(
			Color(0.03, 0.18, 0.25, 0.96), Color(0.32, 0.70, 0.86, 0.55), 2, 4))
		quiet.add_theme_stylebox_override("focus", _style(
			Color(0.08, 0.34, 0.42, 0.9), Color(0.85, 0.98, 1.0, 0.95), 2, 8))
		quiet.add_theme_font_size_override("font_size", 20)
		quiet.add_theme_color_override("font_color", TEXT)


func _style(bg: Color, border: Color, width: int, glow: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(14)
	style.set_border_width_all(width)
	style.border_color = border
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = glow
	style.shadow_offset = Vector2(0, 4)
	return style


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Mark it handled first: the scene change below frees this node, and
		# get_viewport() is null afterwards.
		get_viewport().set_input_as_handled()
		_on_menu_pressed()


func _on_next_pressed() -> void:
	GameManager.next_level()


## A retry after a clear starts a fresh attempt, including a fresh clock.
func _on_retry_pressed() -> void:
	GameManager.start_level(GameManager.current_level)


func _on_menu_pressed() -> void:
	GameManager.return_to_level_select()
