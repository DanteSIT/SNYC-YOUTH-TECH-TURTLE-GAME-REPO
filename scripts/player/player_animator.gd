extends Node3D

const ANIM_IDLE := "IDLE"
const ANIM_SWIM := "SWIMMING"
const ANIM_EAT := "EAT"
const ANIM_HURT := "HURT"

const TILT_UP := -PI / 25.0
const TILT_DOWN := PI / 25.0
const BASE_SPEED_SCALE := 1.0
const BOOST_SPEED_SCALE := 1.5

@onready var _odysse: Node3D = get_node("../Odysse")
@onready var _anim: AnimationPlayer = _odysse.get_node("AnimationPlayer")

const EAT_ANIM: Animation = preload("res://scenes/player/animations/eat.tres")
const HURT_ANIM: Animation = preload("res://scenes/player/animations/hurt.tres")

var _override := ""
var _override_timer := -1.0


func _ready() -> void:
	for anim_name in [ANIM_IDLE, ANIM_SWIM]:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop = true
	var library := _anim.get_animation_library("") as AnimationLibrary
	if library == null:
		library = AnimationLibrary.new()
		_anim.add_animation_library("", library)
	var player := _anim.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player:
		var library := player.get_animation_library("") if player.has_animation_library("") else null
		if library:
			if not library.has_animation(ANIM_EAT):
				library.add_animation(ANIM_EAT, EAT_ANIM)
			if not library.has_animation(ANIM_HURT):
				library.add_animation(ANIM_HURT, HURT_ANIM)
			player.play(ANIM_IDLE)


func update_movement(direction: float, swimming: bool, boosting: bool, vertical_velocity: float, delta: float) -> void:
	_odysse.rotation.y = (1.0 + direction) * PI / 2.0

	var target_tilt := 0.0
	if vertical_velocity > 0.0:
		target_tilt = TILT_UP
	elif vertical_velocity < 0.0:
		target_tilt = TILT_DOWN
	_odysse.rotation.x = lerp(_odysse.rotation.x, target_tilt, delta * 8.0)

	if _override != "":
		_tick_override(delta)
		return

	var anim_name := ANIM_IDLE
	var speed_scale := BASE_SPEED_SCALE
	if swimming:
		anim_name = ANIM_SWIM
		speed_scale = BOOST_SPEED_SCALE if boosting else BASE_SPEED_SCALE

	if _anim.current_animation != anim_name and _anim.has_animation(anim_name):
		_anim.play(anim_name)
	_anim.speed_scale = speed_scale


func play_eat() -> void:
	play_override(ANIM_EAT, 0.6)


func play_hurt() -> void:
	play_override(ANIM_HURT, 0.5)


func play_override(anim_name: String, duration := -1.0) -> void:
	if not _anim.has_animation(anim_name):
		return
	_override = anim_name
	_override_timer = duration
	_anim.speed_scale = 1.0
	_anim.play(anim_name)


func _tick_override(delta: float) -> void:
	if _override_timer > 0.0:
		_override_timer -= delta
		if _override_timer <= 0.0:
			_override = ""
	elif _anim.current_animation != _override:
		_override = ""