extends SceneTree
## Checks the level select cards against a known set of progress records.
##
## Sets records in memory only, so the real save file is never touched.
##
## Usage: godot --headless --path . --script res://tools/probe_level_select.gd

const SCENE := "res://scenes/ui/level_select.tscn"
const PROBE_PATH := "user://probe_level_select.cfg"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var gm: Node = get_root().get_node("GameManager")
	gm.progress_path = PROBE_PATH
	gm.reset_progress(false)
	gm.levels_unlocked = 3
	gm.levels_completed[0] = true
	gm.levels_completed[1] = true
	gm.best_times[0] = 56.9
	gm.best_jelly[0] = 31
	gm.jelly_totals[0] = 32
	gm.best_stars[0] = 3
	gm.best_times[1] = 33.54
	gm.best_jelly[1] = 39
	gm.jelly_totals[1] = 41
	gm.best_stars[1] = 2

	var world := await _load()
	var grid := world.get_node("Grid") as GridContainer
	_expect("one card per level", grid.get_child_count() == gm.LEVELS.size())
	if grid.get_child_count() != gm.LEVELS.size():
		_finish(gm)
		return

	var tutorial := _texts(grid.get_child(0))
	_expect("tutorial shows cleared", tutorial.has("✓  TUTORIAL") and tutorial.has("CLEARED"))
	_expect("tutorial shows best time and jelly",
		tutorial.has("BEST 0:56.90   ·   JELLY 31 / 32"))
	_expect("tutorial shows three stars", tutorial.has("3 / 3 STARS"))

	var level_one := _texts(grid.get_child(1))
	_expect("level 1 shows cleared", level_one.has("✓  LEVEL 1") and level_one.has("CLEARED"))
	_expect("level 1 shows two stars", level_one.has("2 / 3 STARS"))

	# The extra star line must still fit inside the fixed card height.
	var card := grid.get_child(0) as Button
	_expect("card content fits", _content_bottom(card) <= card.get_global_rect().end.y - 2.0)

	var level_two := grid.get_child(2) as Button
	var two := _texts(level_two)
	_expect("level 2 is the next step", two.has("NEXT") and not level_two.disabled)
	_expect("level 2 is unplayed", two.has("Not played yet"))

	var level_three := grid.get_child(3) as Button
	var three := _texts(level_three)
	_expect("level 3 is locked", level_three.disabled and three.has("LOCKED"))
	_expect("locked card explains how to open",
		three.has("Clear Level 2 first"))

	var summary := (world.get_node("Summary") as Label).text
	_expect("summary counts clears", summary.contains("2 of 16 levels cleared"))
	_expect("summary names the next level", summary.contains("Next: Level 2"))

	# The board has to fit between the summary and the back button.
	var grid_rect := grid.get_global_rect()
	var summary_rect := (world.get_node("Summary") as Label).get_global_rect()
	var back_rect := (world.get_node("BackButton") as Button).get_global_rect()
	_expect("summary clears the cards", summary_rect.end.y <= grid_rect.position.y)
	_expect("cards clear the back button", grid_rect.end.y <= back_rect.position.y)
	_expect("cards fit on screen", grid_rect.position.x >= 0.0
		and grid_rect.end.x <= get_root().get_visible_rect().size.x)

	# Unlocking everything should rebuild into a fully playable board.
	gm.unlock_all_levels()
	world._build_grid()
	world._build_summary()
	await process_frame
	_expect("all cards after unlock", grid.get_child_count() == gm.LEVELS.size())
	_expect("last card is selectable", not (grid.get_child(gm.LEVELS.size() - 1) as Button).disabled)

	_finish(gm)


func _finish(gm: Node) -> void:
	gm.reset_progress(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_PATH))
	gm.progress_path = gm.SAVE_PATH
	print("LEVEL SELECT %s" % ("OK" if _failures == 0 else "FAIL"))
	quit(1 if _failures else 0)


func _load() -> Node:
	var packed: PackedScene = load(SCENE)
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	await process_frame
	await process_frame
	return world


func _texts(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		out.append_array(_texts(child))
	return out


func _content_bottom(node: Node) -> float:
	var bottom := 0.0
	if node is Label:
		bottom = maxf(bottom, (node as Label).get_global_rect().end.y)
	for child in node.get_children():
		bottom = maxf(bottom, _content_bottom(child))
	return bottom


func _expect(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %-38s %s" % [label, "ok" if ok else "FAIL"])
