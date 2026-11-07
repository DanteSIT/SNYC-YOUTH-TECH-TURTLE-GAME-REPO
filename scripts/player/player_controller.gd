extends CharacterBody3D

## Feedback burst kinds, matching scripts/effects/feedback_burst.gd.
const BURST_BUBBLES := 0

# All movement numbers live in scripts/core/tuning.gd. Open that file to change
# speed, boost, camera, shake or hit-stop without touching this script.

@export var camera_smoothing := 3.5
@export var camera_boost_smoothing := 8.0
@export var tube_cam_offset := Vector3(0, 0.9, 1.8)
@export var tube_blend_smoothing := 4.0

var boosting := false
var boost_timer := 0.0
var invulnerable := false
var invulnerable_timer := 0.0
var current_flow := 0.0
## Extra backward push used by the tutorial to hold the player at a step until
## they complete it. Normal levels leave this at zero.
var tutorial_push := 0.0

var _cam_rest := Transform3D.IDENTITY
var _cam_anchor := Vector3.ZERO
var _tube_smooth := 0.0
var _pipes: Array[Node3D] = []
var _swim_sound: AudioStreamPlayer
var _shake := 0.0
var _hitstop_until_ms := 0

@onready var _camera: Camera3D = $Camera3D
@onready var _animator: Node3D = $PlayerAnimator
@onready var _visuals: Node3D = $PlayerVisuals
@onready var _trail: GPUParticles3D = $GPUParticles3D


func _ready() -> void:
	Engine.time_scale = 1.0
	_shake = 0.0
	_hitstop_until_ms = 0
	tutorial_push = 0.0
	_swim_sound = $SwimSound
	_swim_sound.bus = "SFX"
	if _swim_sound.stream is AudioStreamMP3:
		_swim_sound.stream.loop = true
	_cam_rest = _camera.transform
	_cam_anchor = global_position
	var root := get_parent().get_parent()
	for pipe_name in ["StartPipe", "EndPipe"]:
		var pipe := root.get_node_or_null(pipe_name) as Node3D
		if pipe:
			_pipes.append(pipe)


func _tube_blend() -> float:
	if _pipes.is_empty():
		return 0.0
	var best := 0.0
	for pipe in _pipes:
		var dz := absf(global_position.z - pipe.global_position.z)
		var radial := Vector2(
			global_position.x - pipe.global_position.x,
			global_position.y - pipe.global_position.y).length()
		var zt := clampf(1.0 - (dz - Tuning.Player.PIPE_CAMERA_HALF_LENGTH) / Tuning.Player.PIPE_CAMERA_FALLOFF, 0.0, 1.0)
		var rt := clampf(1.0 - (radial - Tuning.Player.PIPE_CAMERA_RADIUS) / Tuning.Player.PIPE_CAMERA_FALLOFF, 0.0, 1.0)
		best = maxf(best, minf(zt, rt))
	return best


func _process(delta: float) -> void:
	var smoothing := camera_boost_smoothing if (boosting and boost_timer <= 0) else camera_smoothing
	var k := 1.0 - exp(-smoothing * delta)
	_cam_anchor = _cam_anchor.lerp(global_position, k)
	var trail := global_position - _cam_anchor
	if trail.length() > Tuning.Player.CAMERA_MAX_LAG:
		_cam_anchor = global_position - trail.normalized() * Tuning.Player.CAMERA_MAX_LAG
	_tube_smooth = lerp(_tube_smooth, _tube_blend(), 1.0 - exp(-tube_blend_smoothing * delta))
	var rest_origin := _cam_rest.origin.lerp(tube_cam_offset, _tube_smooth)
	var shake_pos := Vector3.ZERO
	var shake_roll := 0.0
	if _shake > 0.0:
		_shake = maxf(_shake - delta * Tuning.Feel.SHAKE_DECAY, 0.0)
		var amp := _shake * _shake
		shake_pos = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * amp * Tuning.Feel.SHAKE_POSITION
		shake_roll = randf_range(-1.0, 1.0) * amp * Tuning.Feel.SHAKE_ROLL
	_camera.global_position = _cam_anchor + global_basis * rest_origin + shake_pos
	_camera.look_at(global_position + Vector3(0, Tuning.Player.CAMERA_LOOK_HEIGHT, 0), Vector3.UP)
	if not is_zero_approx(shake_roll):
		_camera.rotate_object_local(Vector3.FORWARD, shake_roll)


func _physics_process(delta: float) -> void:
	_update_hitstop()

	if invulnerable:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0:
			invulnerable = false

	velocity.x = 0

	# Gravity stays on inside pipes too. The convex tube walls let the turtle
	# slide along the bottom, and turning gravity off made it hover and snag.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept"):
		velocity.y = Tuning.Player.JUMP_SPEED

	# get_axis takes (negative, positive), so down comes first here.
	var swim := Input.get_axis("ui_down", "ui_up")
	if not is_zero_approx(swim):
		velocity.y = swim * Tuning.Player.SWIM_SPEED

	# Above the roof line, replace upward speed with a gentle downward push.
	# The push grows with height, so the turtle settles instead of escaping.
	var over_roof := global_position.y - Tuning.Player.ROOF_HEIGHT
	if over_roof > 0.0:
		velocity.y = minf(velocity.y, -Tuning.Player.ROOF_PUSH * over_roof)

	var direction := Input.get_axis("ui_left", "ui_right")
	var is_boosting = Input.is_action_pressed("shift")
	var speed := Tuning.Player.SPEED

	if is_boosting and not boosting:
		boosting = true
		boost_timer = Tuning.Player.BOOST_DELAY
		_add_shake(Tuning.Feel.SHAKE_BOOST)

	if boosting and boost_timer > 0:
		boost_timer -= delta

	if boost_timer <= 0 and boosting:
		speed = Tuning.Player.BOOST_SPEED

	var swimming := false
	if direction:
		velocity.z = -direction * speed
		swimming = true
		var boosting_now := boosting and boost_timer <= 0
		if not _swim_sound.playing:
			_swim_sound.play()
		_swim_sound.pitch_scale = 1.35 if boosting_now else 1.0
		if _trail != null:
			_trail.amount_ratio = 1.0 if boosting_now else 0.3
			_trail.speed_scale = 1.8 if boosting_now else 1.0
	else:
		velocity.z = move_toward(velocity.z, 0, speed)
		boosting = false
		boost_timer = 0.0
		if _swim_sound.playing:
			_swim_sound.stop()
		if _trail != null:
			_trail.amount_ratio = 0.3
			_trail.speed_scale = 1.0

	_animator.update_movement(direction, swimming, boosting, velocity.y, delta)

	velocity.z += current_flow + tutorial_push
	move_and_slide()

	if global_position.y < Tuning.Player.FALL_LIMIT:
		GameManager.take_damage(GameManager.MAX_HEALTH)

	var target_fov = Tuning.Player.BOOST_FOV if (boosting and boost_timer <= 0) else Tuning.Player.CAMERA_FOV
	_camera.fov = lerp(_camera.fov, target_fov, delta * Tuning.Player.FOV_LERP_SPEED)


func set_flow(value: float) -> void:
	current_flow = value


## Used by the tutorial to ease the player back if they reach a step's gate
## before doing what the step asks.
func set_tutorial_push(value: float) -> void:
	tutorial_push = value


## Jump the follow camera straight to the body, for tutorial respawns.
func snap_camera_to_body() -> void:
	_cam_anchor = global_position


func take_damage(amount: int) -> void:
	if invulnerable:
		return
	invulnerable = true
	invulnerable_timer = Tuning.Player.INVULNERABLE_SECONDS
	_animator.play_hurt()
	_visuals.flash_damage()
	_add_shake(Tuning.Feel.SHAKE_DAMAGE)
	_start_hitstop()
	_spawn_burst(BURST_BUBBLES)
	GameManager.take_damage(amount)


func _add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 1.0)


## Brief freeze when the turtle is hit. The deadline uses wall-clock time
## because Time.get_ticks_msec() ignores Engine.time_scale.
func _start_hitstop() -> void:
	if get_tree().paused:
		return
	_hitstop_until_ms = Time.get_ticks_msec() + int(Tuning.Feel.HITSTOP_SECONDS * 1000.0)
	Engine.time_scale = Tuning.Feel.HITSTOP_TIME_SCALE


func _update_hitstop() -> void:
	if _hitstop_until_ms == 0:
		return
	if Time.get_ticks_msec() < _hitstop_until_ms:
		Engine.time_scale = Tuning.Feel.HITSTOP_TIME_SCALE
		return
	_hitstop_until_ms = 0
	Engine.time_scale = 1.0


## A fatal hit can free this node mid-freeze, so restore the time scale on exit.
func _exit_tree() -> void:
	if _hitstop_until_ms != 0:
		_hitstop_until_ms = 0
		Engine.time_scale = 1.0


func _spawn_burst(kind: int) -> void:
	var burst := (load(Tuning.Assets.FEEDBACK_BURST) as PackedScene).instantiate()
	burst.kind = kind
	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(burst)
	burst.global_position = global_position + Vector3(0, 0.35, 0)
