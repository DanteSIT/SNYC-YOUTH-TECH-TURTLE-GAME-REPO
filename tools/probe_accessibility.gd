extends SceneTree
## Checks the large-text option scales menus but leaves the in-level HUD alone.
##
## Uses its own save file so the real accessibility settings are untouched.
##
## Usage: godot --headless --path . --script res://tools/probe_accessibility.gd

const MENU := "res://scenes/ui/menu.tscn"
const SETTINGS := "res://scenes/ui/settings.tscn"
const LEVEL_SELECT := "res://scenes/ui/level_select.tscn"
const RESULTS := "res://scenes/ui/level_complete.tscn"
const TURTLE := "res://scenes/player/turtle.tscn"
const PROBE_PATH := "user://probe_accessibility.cfg"
const PROGRESS_PATH := "user://probe_accessibility_progress.cfg"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var access: Node = get_root().get_node("Accessibility")
	access.save_path = PROBE_PATH
	access.set_text_scale(0)

	var gm: Node = get_root().get_node("GameManager")
	gm.progress_path = PROGRESS_PATH
	gm.reset_progress(false)
	gm.levels_unlocked = 3
	gm.levels_completed[0] = true
	gm.levels_completed[1] = true
	gm.best_times[1] = 41.83
	gm.best_jelly[1] = 9
	gm.jelly_totals[1] = 10
	gm.best_stars[1] = 3

	var menu := await _load(MENU)
	var play := menu.get_node("Menu/PlayButton") as Button
	var title := menu.get_node("Menu/Title") as Label
	var normal_button := play.get_theme_font_size("font_size")
	var normal_title := title.label_settings.font_size
	_expect("menu starts at normal size", normal_button > 0 and normal_title == 64)

	access.set_text_scale(1)
	_expect("button text grows", play.get_theme_font_size("font_size") > normal_button)
	_expect("label settings grow", title.label_settings.font_size > normal_title)
	_expect("label settings are copied per label",
		title.label_settings.has_meta("ui_base_font_size"))
	menu.queue_free()
	await process_frame

	# The settings screen should open on the saved choice. The option lives on
	# the SettingsUI child, not on the scene root.
	var settings := await _load(SETTINGS)
	var text_size := settings.get_node("SettingsUI")._text_size_option as OptionButton
	_expect("settings shows large text", text_size != null and text_size.selected == 1)
	settings.queue_free()
	await process_frame

	# Card text must still fit the fixed card height at the larger size.
	var select := await _load(LEVEL_SELECT)
	var grid := select.get_node("Grid") as GridContainer
	var clipped := 0
	for card in grid.get_children():
		var col := card.get_child(0).get_child(0) as VBoxContainer
		if col.get_combined_minimum_size().y > (card as Button).size.y - 24.0:
			clipped += 1
	_expect("level cards fit at large text", clipped == 0)
	select.queue_free()
	await process_frame

	# The results panel is fixed too: the blocks must not overlap.
	gm.current_level = 1
	gm.level_time = 41.83
	gm.jellyfish = 9
	gm.level_jellyfish_total = 10
	gm.damage_taken = 0
	gm.record_level_result()
	var results := await _load(RESULTS)
	var last_bottom := 0.0
	var stacked := true
	for path in ["Title", "StarRow", "Hints", "StatsLabel", "BestLabel", "Buttons"]:
		var rect := (results.get_node(path) as Control).get_global_rect()
		stacked = stacked and rect.position.y >= last_bottom - 1.0
		last_bottom = rect.end.y
	var panel := (results.get_node("Panel") as Control).get_global_rect()
	_expect("results blocks stay stacked", stacked)
	_expect("results buttons stay in the panel", last_bottom <= panel.end.y)
	results.queue_free()
	await process_frame

	# The HUD has a fixed layout, so its labels must keep their scene sizes.
	var turtle := await _load(TURTLE)
	var health := turtle.get_node("CanvasLayer/HealthLabel") as Label
	_expect("HUD text keeps its size", health.label_settings.font_size == 23)
	turtle.queue_free()
	await process_frame

	# The choice survives a save/load round-trip.
	access.text_scale_index = 0
	access.load_settings()
	_expect("large text is remembered", access.get_text_scale_index() == 1)

	access.set_text_scale(0)
	gm.reset_progress(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	access.save_path = access.SAVE_PATH
	gm.progress_path = gm.SAVE_PATH
	print("ACCESSIBILITY %s" % ("OK" if _failures == 0 else "FAIL"))
	quit(1 if _failures else 0)


func _load(path: String) -> Node:
	var packed: PackedScene = load(path)
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	await process_frame
	await process_frame
	return world


func _expect(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %-38s %s" % [label, "ok" if ok else "FAIL"])
