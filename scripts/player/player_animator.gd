extends Node3D

## Plays the turtle's model animations. Everything a beginner might swap (the
## model, its animation player, the clip names and the eat/hurt clips) is
## exported, so it can be changed in the inspector without editing this script.

## The model node that is rotated and animated.
@export var model_path: NodePath = ^"../Odysse"
## Where the AnimationPlayer lives inside the model.
@export var animation_player_path: NodePath = ^"AnimationPlayer"

@export var idle_animation := "IDLE"
@export var swim_animation := "SWIMMING"
@export var eat_animation_name := "EAT"
@export var hurt_animation_name := "HURT"

## Extra one-shot clips added to the model's library at startup.
@export var eat_animation: Animation = preload("res://scenes/player/animations/eat.tres")
@export var hurt_animation: Animation = preload("res://scenes/player/animations/hurt.tres")

var _model: Node3D
var _anim: AnimationPlayer
var _override := ""
var _override_timer := -1.0


func _ready() -> void:
	_model = get_node_or_null(model_path) as Node3D
	if _model != null:
		_anim = _model.get_node_or_null(animation_player_path) as AnimationPlayer
	if _anim == null:
		return
	for anim_name in [idle_animation, swim_animation]:
		if _anim.has_animation(anim_name):
			_anim.get_animation(anim_name).loop = true
	var library := _anim.get_animation_library("") as AnimationLibrary
	if library == null:
		library = AnimationLibrary.new()
		_anim.add_animation_library("", library)
	_add_extra(eat_animation_name, eat_animation, library)
	_add_extra(hurt_animation_name, hurt_animation, library)
	_anim.play(idle_animation)


func _add_extra(anim_name: String, clip: Animation, library: AnimationLibrary) -> void:
	if clip == null or library.has_animation(anim_name):
		return
	library.add_animation(anim_name, clip)


func update_movement(direction: float, swimming: bool, boosting: bool,
		vertical_velocity: float, delta: float) -> void:
	if _model != null:
		if direction != 0.0:
			_model.rotation.y = (1.0 + direction) * PI / 2.0
		var target_tilt := 0.0
		if vertical_velocity > 0.0:
			target_tilt = -Tuning.Player.TILT_ANGLE
		elif vertical_velocity < 0.0:
			target_tilt = Tuning.Player.TILT_ANGLE
		_model.rotation.x = lerp(_model.rotation.x, target_tilt,
			delta * Tuning.Player.TILT_SPEED)

	if _override != "":
		_tick_override(delta)
		return

	var anim_name := idle_animation
	var speed_scale := Tuning.Player.IDLE_ANIM_SPEED
	if swimming:
		anim_name = swim_animation
		speed_scale = Tuning.Player.BOOST_ANIM_SPEED if boosting \
			else Tuning.Player.IDLE_ANIM_SPEED

	if _anim == null:
		return
	if _anim.current_animation != anim_name and _anim.has_animation(anim_name):
		_anim.play(anim_name)
	_anim.speed_scale = speed_scale


func play_eat() -> void:
	play_override(eat_animation_name, Tuning.Player.EAT_ANIM_SECONDS)


func play_hurt() -> void:
	play_override(hurt_animation_name, Tuning.Player.HURT_ANIM_SECONDS)


func play_override(anim_name: String, duration := -1.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
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
	elif _anim and _anim.current_animation != _override:
		_override = ""
