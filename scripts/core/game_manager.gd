extends Node

signal score_changed(value: int)
signal health_changed(value: int)
signal jellyfish_changed(value: int)
signal game_over

const MAX_HEALTH := 100
const START_LIVES := 3

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

## Play time in the current level, in seconds. Lives here rather than in the HUD
## because reaching the goal replaces the whole level scene with the results
## screen, so anything the results screen wants to show has to outlive the HUD.
var level_time := 0.0

## How many jellyfish the current level actually contains. Collected count alone
## cannot answer "how many did I miss", and the level's collectable nodes are
## freed as they are picked up.
var level_jellyfish_total := 0

## Fastest clear of each level this session, indexed like LEVELS. 0.0 means no
## clear yet. Session-scoped on purpose: campaign progress is not persisted
## either, so a saved best time next to a reset level list would be odd.
var best_times: Array[float] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	best_times.resize(LEVELS.size())


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func add_jellyfish(amount: int) -> void:
	jellyfish += amount
	jellyfish_changed.emit(jellyfish)


func take_damage(amount: int) -> void:
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
	if best_times.size() != LEVELS.size():
		best_times.resize(LEVELS.size())
	var idx: int = clampi(current_level, 0, best_times.size() - 1)
	if best_times[idx] > 0.0 and best_times[idx] <= level_time:
		return false
	best_times[idx] = level_time
	return true


func best_time_for_level(index: int) -> float:
	if index < 0 or index >= best_times.size():
		return 0.0
	return best_times[index]


## M:SS.hh, the single format used by the HUD and the results screen so the two
## never disagree. Hundredths rather than tenths because tenths can round a
## 59.96 up to a "60.0" that is not a real time.
static func format_time(seconds: float) -> String:
	var m: int = int(maxf(0.0, seconds)) / 60
	return "%d:%05.2f" % [m, fmod(maxf(0.0, seconds), 60.0)]


func complete_level() -> void:
	record_finish_time()
	GameFlow.to_level_complete()


func next_level() -> void:
	if current_level + 1 < LEVELS.size():
		levels_unlocked = maxi(levels_unlocked, current_level + 2)
		start_level(current_level + 1)
	else:
		GameFlow.to_menu()


func return_to_level_select() -> void:
	GameFlow.to_level_select()
