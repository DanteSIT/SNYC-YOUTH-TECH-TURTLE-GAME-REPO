extends SceneTree
## Checks the campaign save file round-trips and that records only improve.
##
## Uses its own file so running the probe never overwrites real progress.
##
## Usage: godot --headless --path . --script res://tools/probe_progress.gd

const PROBE_PATH := "user://probe_progress.cfg"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gm: Node = get_root().get_node("GameManager")
	gm.progress_path = PROBE_PATH
	gm.reset_progress(false)

	_expect("fresh save has no progress", gm.has_progress() == false)
	_expect("fresh continue points at tutorial", gm.continue_index() == 0)

	# Clearing level 1 records the result and unlocks level 2.
	gm.current_level = 1
	gm.level_time = 42.5
	gm.jellyfish = 7
	gm.level_jellyfish_total = 9
	gm.record_level_result()

	_expect("clear unlocks next level", gm.levels_unlocked == 3)
	_expect("clear marks level completed", gm.is_level_completed(1))
	_expect("clear stores best time", is_equal_approx(gm.best_time_for_level(1), 42.5))
	_expect("clear stores best jelly", gm.best_jelly_for_level(1) == 7)
	_expect("clear stores stars", gm.best_stars_for_level(1) == 2)
	_expect("continue points at next level", gm.continue_index() == 2)
	_expect("save file was written", FileAccess.file_exists(PROBE_PATH))

	gm.reset_progress(false)
	_expect("reset clears memory", gm.levels_unlocked == 1 and not gm.has_progress())
	gm.load_progress()
	_expect("load restores unlock", gm.levels_unlocked == 3)
	_expect("load restores completion", gm.is_level_completed(1))
	_expect("load restores time", is_equal_approx(gm.best_time_for_level(1), 42.5))
	_expect("load restores jelly", gm.best_jelly_for_level(1) == 7)
	_expect("load restores stars", gm.best_stars_for_level(1) == 2)

	# A slower, worse run must not overwrite the records.
	gm.current_level = 1
	gm.level_time = 99.0
	gm.jellyfish = 2
	gm.level_jellyfish_total = 9
	gm.record_level_result()
	_expect("slower clear keeps best time",
		is_equal_approx(gm.best_time_for_level(1), 42.5))
	_expect("smaller catch keeps best jelly", gm.best_jelly_for_level(1) == 7)

	gm.level_time = 30.0
	gm.record_level_result()
	_expect("faster clear replaces time",
		is_equal_approx(gm.best_time_for_level(1), 30.0))

	# A clear stores the level's jellyfish total for the select screen.
	gm.current_level = 4
	gm.level_time = 10.0
	gm.jellyfish = 12
	gm.level_jellyfish_total = 12
	gm.damage_taken = 0
	gm.record_level_result()
	_expect("perfect clear earns three stars", gm.best_stars_for_level(4) == 3)

	# A later hit run must not lower the stored star record.
	gm.level_time = 20.0
	gm.damage_taken = 25
	gm.record_level_result()
	_expect("stars only improve", gm.best_stars_for_level(4) == 3)
	_expect("hit run itself scores fewer", gm.last_stars == 2)

	gm.reset_progress(false)
	gm.load_progress()
	_expect("load restores jelly total", gm.jelly_total_for_level(4) == 12)
	_expect("load restores perfect stars", gm.best_stars_for_level(4) == 3)

	gm.unlock_all_levels()
	_expect("unlock all opens every level", gm.levels_unlocked == gm.LEVELS.size())

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROBE_PATH))
	gm.reset_progress(false)
	gm.load_progress()
	_expect("missing save keeps defaults", gm.levels_unlocked == 1)

	gm.progress_path = gm.SAVE_PATH
	print("PROGRESS %s" % ("OK" if _failures == 0 else "FAIL"))
	quit(1 if _failures else 0)


func _expect(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %-38s %s" % [label, "ok" if ok else "FAIL"])
