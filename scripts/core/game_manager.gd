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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


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
	score = 0
	jellyfish = 0
	health = MAX_HEALTH
	lives = START_LIVES
	score_changed.emit(score)
	jellyfish_changed.emit(jellyfish)
	health_changed.emit(health)
	GameFlow.change_scene(LEVELS[current_level])


func complete_level() -> void:
	GameFlow.to_level_complete()


func next_level() -> void:
	if current_level + 1 < LEVELS.size():
		levels_unlocked = maxi(levels_unlocked, current_level + 2)
		start_level(current_level + 1)
	else:
		GameFlow.to_menu()


func return_to_level_select() -> void:
	GameFlow.to_level_select()
