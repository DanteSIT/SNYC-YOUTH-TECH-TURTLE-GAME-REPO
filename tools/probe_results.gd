extends SceneTree
## Checks the results screen: stars, best-time callout and button labels.
##
## Records are written to a probe save file so the real campaign is untouched.
##
## Usage: godot --headless --path . --script res://tools/probe_results.gd

const SCENE := "res://scenes/ui/level_complete.tscn"
const PROBE_PATH := "user://probe_results.cfg"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	get_root().size = Vector2i(1280, 720)
	var gm: Node = get_root().get_node("GameManager")
	gm.progress_path = PROBE_PATH
	gm.reset_progress(false)

	# A clean run with every jellyfish earns all three stars.
	gm.current_level = 1
	gm.level_time = 40.0
	gm.jellyfish = 9
	gm.level_jellyfish_total = 9
	gm.damage_taken = 0
	gm.record_level_result()
	var perfect := await _load()
	_expect("perfect run earns three stars", gm.last_stars == 3)
	_expect("star row shows three stars", _stars(perfect) == 3)
	_expect("title names the level", _label(perfect, "Title") == "Level 1 Complete!")
	_expect("stats show time and jelly",
		_label(perfect, "StatsLabel").contains("Time 0:40.00")
		and _label(perfect, "StatsLabel").contains("Jelly 9 / 9"))
	_expect("first clear is called out", _label(perfect, "BestLabel") == "FIRST CLEAR")
	_expect("all hints are earned", _earned_hints(perfect) == 3)
	_expect("next button goes forward",
		(_button(perfect, "NextButton") as Button).text == "NEXT LEVEL")

	# The panel is fixed-size, so every block has to fit and stack cleanly.
	var panel := _rect(perfect, "Panel")
	var title := _rect(perfect, "Title")
	var star_row := _rect(perfect, "StarRow")
	var hints := _rect(perfect, "Hints")
	var stats := _rect(perfect, "StatsLabel")
	var best := _rect(perfect, "BestLabel")
	var buttons := _rect(perfect, "Buttons")
	_expect("title clears the stars", title.end.y <= star_row.position.y)
	_expect("stars clear the hints", star_row.end.y <= hints.position.y)
	_expect("hints clear the stats", hints.end.y <= stats.position.y)
	_expect("stats clear the best line", stats.end.y <= best.position.y)
	_expect("best line clears the buttons", best.end.y <= buttons.position.y)
	_expect("buttons fit in the panel", buttons.end.y <= panel.end.y)
	_expect("buttons fit on screen", buttons.position.x >= 0.0
		and buttons.end.x <= get_root().get_visible_rect().size.x)
	perfect.queue_free()
	await process_frame

	# A slower run that misses jelly and takes a hit only earns the finish star.
	gm.level_time = 99.0
	gm.jellyfish = 1
	gm.damage_taken = 25
	gm.record_level_result()
	var rough := await _load()
	_expect("rough run earns one star", gm.last_stars == 1)
	_expect("star row shows one star", _stars(rough) == 1)
	_expect("only the finish hint is earned", _earned_hints(rough) == 1)
	_expect("existing best time is shown",
		_label(rough, "BestLabel") == "BEST 0:40.00")
	_expect("records only improve", is_equal_approx(gm.best_time_for_level(1), 40.0))
	rough.queue_free()
	await process_frame

	# Beating the old time announces the record.
	gm.level_time = 30.0
	gm.jellyfish = 9
	gm.damage_taken = 0
	gm.record_level_result()
	var faster := await _load()
	_expect("faster run is a new best", gm.last_new_best)
	_expect("new best names the old time",
		_label(faster, "BestLabel").contains("NEW BEST TIME")
		and _label(faster, "BestLabel").contains("0:40.00"))
	_expect("stars are kept at their best", gm.best_stars_for_level(1) == 3)
	faster.queue_free()
	await process_frame

	# The last level cannot go forward, so the button returns to the menu.
	gm.current_level = gm.LEVELS.size() - 1
	gm.level_time = 20.0
	gm.jellyfish = 0
	gm.level_jellyfish_total = 0
	gm.damage_taken = 0
	gm.record_level_result()
	var last := await _load()
	_expect("empty jelly list still earns its star", gm.last_stars == 3)
	_expect("last level returns to the menu",
		(_button(last, "NextButton") as Button).text == "MAIN MENU")
	_expect("last level title is correct",
		_label(last, "Title") == "Level 15 Complete!")
	last.queue_free()
	await process_frame

	gm.reset_progress(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_PATH))
	gm.progress_path = gm.SAVE_PATH
	print("RESULTS %s" % ("OK" if _failures == 0 else "FAIL"))
	quit(1 if _failures else 0)


func _load() -> Node:
	var packed: PackedScene = load(SCENE)
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	await process_frame
	await process_frame
	return world


func _stars(world: Node) -> int:
	return int(world.get_node("StarRow").stars)


func _label(world: Node, path: String) -> String:
	return (world.get_node(path) as Label).text


func _button(world: Node, name: String) -> Button:
	return world.get_node("Buttons/" + name) as Button


func _rect(world: Node, path: String) -> Rect2:
	return (world.get_node(path) as Control).get_global_rect()


func _earned_hints(world: Node) -> int:
	var earned := 0
	for child in world.get_node("Hints").get_children():
		if (child as Label).text.begins_with("✓"):
			earned += 1
	return earned


func _expect(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %-38s %s" % [label, "ok" if ok else "FAIL"])
