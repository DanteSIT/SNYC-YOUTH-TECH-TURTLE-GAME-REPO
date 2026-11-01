extends Node

signal score_changed(value: int)
signal health_changed(value: int)
signal jellyfish_changed(value: int)
signal game_over

const MAX_HEALTH := 100
const START_LIVES := 3

const SAVE_PATH := "user://progress.cfg"
const SAVE_VERSION := 1

## A clear earns three stars: finish, collect most of the jellyfish, and take no
## damage. 80% leaves room for a missed collectable without losing the star.
const STARS := 3
const JELLY_STAR_RATIO := 0.8

const LEVELS: Array[String] = [
	"res://scenes/levels/tutorial.tscn",
	"res://scenes/levels/level_1.tscn",
	"res://scenes/levels/level_2.tscn",
	"res://scenes/levels/level_3.tscn",
	"res://scenes/levels/level_4.tscn",
	"res://scenes/levels/level_5.tscn",
	"res://scenes/levels/level_6.tscn",
	"res://scenes/levels/level_7.tscn",
	"res://scenes/levels/level_8.tscn",
	"res://scenes/levels/level_9.tscn",
	"res://scenes/levels/level_10.tscn",
	"res://scenes/levels/level_11.tscn",
	"res://scenes/levels/level_12.tscn",
	"res://scenes/levels/level_13.tscn",
	"res://scenes/levels/level_14.tscn",
	"res://scenes/levels/level_15.tscn",
]

var score := 0
var jellyfish := 0
var health := MAX_HEALTH
var lives := START_LIVES
var current_level := 0
var levels_unlocked := 1

## Damage taken during the current attempt. Kept separate from health because a
## healed hit still costs the no-damage star.
var damage_taken := 0

## The result of the clear that opened the results screen. Read by the screen so
## it does not have to recompute stars after the level scene is gone.
var last_stars := 0
var last_new_best := false
var last_previous_best := 0.0

## The tutorial step the player is on. Kept here so losing a life reloads the
## tutorial at the same step instead of starting the whole lesson again.
var tutorial_stage := 0

## Play time in the current level, in seconds. Lives here rather than in the HUD
## because reaching the goal replaces the whole level scene with the results
## screen, so anything the results screen wants to show has to outlive the HUD.
var level_time := 0.0

## How many jellyfish the current level actually contains. Collected count alone
## cannot answer "how many did I miss", and the level's collectable nodes are
## freed as they are picked up.
var level_jellyfish_total := 0

## Per-level records, all indexed like LEVELS. A best time of 0.0 means the level
## has not been cleared yet.
var best_times: Array[float] = []
var best_jelly: Array[int] = []
var best_stars: Array[int] = []
var jelly_totals: Array[int] = []
var levels_completed: Array[bool] = []

## Overridable so tools can exercise save/load without touching the real file.
var progress_path := SAVE_PATH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resize_progress()
	load_progress()


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func add_jellyfish(amount: int) -> void:
	jellyfish += amount
	jellyfish_changed.emit(jellyfish)


func take_damage(amount: int) -> void:
	damage_taken += amount
	health = maxi(0, health - amount)
	health_changed.emit(health)
	if health > 0:
		return
	lives -= 1
	if lives <= 0:
		game_over.emit()
		GameFlow.to_game_over()
	else:
		health = MAX_HEALTH
		health_changed.emit(health)
		GameFlow.restart_current_level()


func heal(amount: int) -> void:
	health = mini(MAX_HEALTH, health + amount)
	health_changed.emit(health)


func start_level(index: int) -> void:
	current_level = clampi(index, 0, LEVELS.size() - 1)
	# Entering the tutorial from a menu starts the lesson over. A life lost
	# mid-lesson reloads through restart_current_level(), which keeps the step.
	if current_level == 0:
		tutorial_stage = 0
	lives = START_LIVES
	reset_level_progress()
	GameFlow.change_scene(LEVELS[current_level])


## Clears everything that belongs to a single attempt at a level. Lives are
## deliberately untouched: retrying after a death must not hand back lives, only
## the progress of the attempt that just ended.
func reset_level_progress() -> void:
	score = 0
	jellyfish = 0
	level_time = 0.0
	level_jellyfish_total = 0
	damage_taken = 0
	last_stars = 0
	last_new_best = false
	last_previous_best = 0.0
	health = MAX_HEALTH
	score_changed.emit(score)
	jellyfish_changed.emit(jellyfish)
	health_changed.emit(health)


func advance_level_time(delta: float) -> void:
	level_time += delta


func set_level_jellyfish_total(count: int) -> void:
	level_jellyfish_total = maxi(0, count)


## Jellyfish present in the level that the player did not collect.
func jellyfish_missed() -> int:
	return maxi(0, level_jellyfish_total - jellyfish)


## Banks the attempt's time as this level's best. Returns true on a new record.
func record_finish_time() -> bool:
	_resize_progress()
	var idx: int = clampi(current_level, 0, best_times.size() - 1)
	if best_times[idx] > 0.0 and best_times[idx] <= level_time:
		return false
	best_times[idx] = level_time
	return true


func best_time_for_level(index: int) -> float:
	if index < 0 or index >= best_times.size():
		return 0.0
	return best_times[index]


func best_jelly_for_level(index: int) -> int:
	if index < 0 or index >= best_jelly.size():
		return 0
	return best_jelly[index]


func best_stars_for_level(index: int) -> int:
	if index < 0 or index >= best_stars.size():
		return 0
	return best_stars[index]


## Whether this attempt collected enough jellyfish for the second star. A level
## with no jellyfish cannot lose the star.
func earned_jelly_star() -> bool:
	if level_jellyfish_total <= 0:
		return true
	var needed := int(ceil(level_jellyfish_total * JELLY_STAR_RATIO))
	return jellyfish >= needed


func earned_no_damage_star() -> bool:
	return damage_taken <= 0


## The stars this attempt is worth. Finishing always earns the first one.
func calculate_stars() -> int:
	var stars := 1
	if earned_jelly_star():
		stars += 1
	if earned_no_damage_star():
		stars += 1
	return clampi(stars, 0, STARS)


func jelly_total_for_level(index: int) -> int:
	if index < 0 or index >= jelly_totals.size():
		return 0
	return jelly_totals[index]


func is_level_completed(index: int) -> bool:
	if index < 0 or index >= levels_completed.size():
		return false
	return levels_completed[index]


## True once the player has cleared anything, so the menu can offer Continue
## instead of starting a brand-new run.
func has_progress() -> bool:
	if levels_unlocked > 1:
		return true
	for done in levels_completed:
		if done:
			return true
	return false


## The level a Continue press should open: the furthest unlocked one.
func continue_index() -> int:
	return clampi(levels_unlocked - 1, 0, LEVELS.size() - 1)


func continue_game() -> void:
	start_level(continue_index() if has_progress() else 0)


## M:SS.hh, the single format used by the HUD and the results screen so the two
## never disagree. Hundredths rather than tenths because tenths can round a
## 59.96 up to a "60.0" that is not a real time.
static func format_time(seconds: float) -> String:
	var m: int = int(maxf(0.0, seconds)) / 60
	return "%d:%05.2f" % [m, fmod(maxf(0.0, seconds), 60.0)]


## Stores everything a clear earns: best time, best jelly count, completion, and
## the next unlock. Split from complete_level() so tools can test it without a
## scene change.
func record_level_result() -> bool:
	_resize_progress()
	var idx: int = clampi(current_level, 0, LEVELS.size() - 1)
	last_previous_best = best_times[idx]
	last_new_best = record_finish_time()
	last_stars = calculate_stars()
	levels_completed[idx] = true
	best_jelly[idx] = maxi(best_jelly[idx], jellyfish)
	best_stars[idx] = maxi(best_stars[idx], last_stars)
	jelly_totals[idx] = maxi(jelly_totals[idx], level_jellyfish_total)
	levels_unlocked = maxi(levels_unlocked, mini(idx + 2, LEVELS.size()))
	save_progress()
	return last_new_best


func complete_level() -> void:
	record_level_result()
	GameFlow.to_level_complete()


func next_level() -> void:
	if current_level + 1 < LEVELS.size():
		levels_unlocked = maxi(levels_unlocked, current_level + 2)
		save_progress()
		start_level(current_level + 1)
	else:
		GameFlow.to_menu()


func unlock_all_levels() -> void:
	levels_unlocked = LEVELS.size()
	save_progress()


func reset_progress(save := true) -> void:
	levels_unlocked = 1
	_resize_progress()
	best_times.fill(0.0)
	best_jelly.fill(0)
	best_stars.fill(0)
	jelly_totals.fill(0)
	levels_completed.fill(false)
	if save:
		save_progress()


func _resize_progress() -> void:
	var count := LEVELS.size()
	if best_times.size() != count:
		best_times.resize(count)
	if best_jelly.size() != count:
		best_jelly.resize(count)
	if best_stars.size() != count:
		best_stars.resize(count)
	if jelly_totals.size() != count:
		jelly_totals.resize(count)
	if levels_completed.size() != count:
		levels_completed.resize(count)


## One section per level keeps the file readable and makes a damaged section
## harmless: the rest of the campaign still loads.
func save_progress() -> void:
	_resize_progress()
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "version", SAVE_VERSION)
	cfg.set_value("progress", "unlocked", levels_unlocked)
	for i in LEVELS.size():
		var section := "level_%d" % i
		cfg.set_value(section, "completed", levels_completed[i])
		cfg.set_value(section, "best_time", best_times[i])
		cfg.set_value(section, "best_jelly", best_jelly[i])
		cfg.set_value(section, "best_stars", best_stars[i])
		cfg.set_value(section, "jelly_total", jelly_totals[i])
	var err := cfg.save(progress_path)
	if err != OK:
		push_warning("Could not save progress to %s (error %d)" % [progress_path, err])


func load_progress() -> void:
	_resize_progress()
	var cfg := ConfigFile.new()
	if cfg.load(progress_path) != OK:
		return
	levels_unlocked = clampi(
		int(cfg.get_value("progress", "unlocked", 1)), 1, LEVELS.size())
	best_times.fill(0.0)
	best_jelly.fill(0)
	best_stars.fill(0)
	jelly_totals.fill(0)
	levels_completed.fill(false)
	for i in LEVELS.size():
		var section := "level_%d" % i
		if not cfg.has_section(section):
			continue
		levels_completed[i] = bool(cfg.get_value(section, "completed", false))
		best_times[i] = float(cfg.get_value(section, "best_time", 0.0))
		best_jelly[i] = int(cfg.get_value(section, "best_jelly", 0))
		best_stars[i] = int(cfg.get_value(section, "best_stars", 0))
		jelly_totals[i] = int(cfg.get_value(section, "jelly_total", 0))


func return_to_level_select() -> void:
	GameFlow.to_level_select()
