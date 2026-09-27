extends CharacterBody3D

const SPEED = 3
const JUMP_VELOCITY = 2
const SWIM_VELOCITY = 3
const BOOST = 4
const BOOST_DELAY = 0.2
const DEFAULT_FOV = 90.0
const BOOST_FOV = 110.0
const INVULNERABLE_TIME = 1.0
const TUBE_HALF_LEN = 2.4
const TUBE_RADIUS = 2.0
const TUBE_FALLOFF = 1.0

# --- game feel (shake / hit-stop / feedback bursts) ---
const SHAKE_DAMAGE := 0.6
const SHAKE_BOOST := 0.22
const SHAKE_DECAY := 1.7
const SHAKE_POS_AMP := 0.16
const SHAKE_ROLL_AMP := 0.055
const HITSTOP_TIME := 0.11
const HITSTOP_SCALE := 0.04
const FEEDBACK_BURST := preload("res://scenes/effects/feedback_burst.tscn")
const BURST_BUBBLES := 0
const BURST_SPARKLE := 1

@export var camera_smoothing := 3.5
@export var camera_boost_smoothing := 8.0
@export var tube_cam_offset := Vector3(0, 0.9, 1.8)
@export var tube_blend_smoothing := 4.0

var boosting := false
var boost_timer := 0.0
var invulnerable := false
var invulnerable_timer := 0.0
var current_flow := 0.0

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
		var zt := clampf(1.0 - (dz - TUBE_HALF_LEN) / TUBE_FALLOFF, 0.0, 1.0)
		var rt := clampf(1.0 - (radial - TUBE_RADIUS) / TUBE_FALLOFF, 0.0, 1.0)
		best = maxf(best, minf(zt, rt))
	return best


func _process(delta: float) -> void:
	var smoothing := camera_boost_smoothing if (boosting and boost_timer <= 0) else camera_smoothing
	var k := 1.0 - exp(-smoothing * delta)
	_cam_anchor = _cam_anchor.lerp(global_position, k)
	var trail := global_position - _cam_anchor
	if trail.length() > 1.0:
		_cam_anchor = global_position - trail.normalized() * 1.0
	_tube_smooth = lerp(_tube_smooth, _tube_blend(), 1.0 - exp(-tube_blend_smoothing * delta))
	var rest_origin := _cam_rest.origin.lerp(tube_cam_offset, _tube_smooth)
	var shake_pos := Vector3.ZERO
	var shake_roll := 0.0
	if _shake > 0.0:
		_shake = maxf(_shake - delta * SHAKE_DECAY, 0.0)
		var amp := _shake * _shake
		shake_pos = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * amp * SHAKE_POS_AMP
		shake_roll = randf_range(-1.0, 1.0) * amp * SHAKE_ROLL_AMP
	_camera.global_position = _cam_anchor + global_basis * rest_origin + shake_pos
	_camera.look_at(global_position + Vector3(0, 0.3, 0), Vector3.UP)
	if not is_zero_approx(shake_roll):
		_camera.rotate_object_local(Vector3.FORWARD, shake_roll)


func _physics_process(delta: float) -> void:
	_update_hitstop()

	if invulnerable:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0:
			invulnerable = false

	velocity.x = 0

	# Plain gravity, including inside a transition pipe. An earlier version made
	# the turtle neutrally buoyant in the bore, on the theory that its curved wall
	# was too steep to stand on. Measurement said otherwise: with the bore built
	# from convex pieces (see transition_pipe.tscn) the turtle slides along the
	# bottom of the tube perfectly well, and the buoyancy was only making things
	# worse -- the turtle hovered at spawn height with is_on_floor() false, which
	# broke the floor probe, and it crawled for up to 2 s against a gate in
	# level_2 that it passed cleanly without it. Traversal went from 30/32 to
	# 32/32 when the buoyancy came out.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept"):
		velocity.y = JUMP_VELOCITY

	# Godot's signature is get_axis(NEGATIVE, POSITIVE): the FIRST action is the
	# one that returns -1. This used to read ("ui_up", "ui_down"), which yielded
	# -1 for ui_up and +1 for ui_down, so the line below turned the up key into a
	# downward push. project.godot binds ui_up to W and the up arrow, so holding W
	# dove, and inside a pipe -- where the only way out is upward -- it drove the
	# turtle straight into the bore wall and jammed it there. Measured: ui_up moved
	# the turtle -1.000 m in y over a third of a second. tools/probe_pipe_clearance.gd
	# checks the polarity, so this cannot quietly invert again.
	var swim := Input.get_axis("ui_down", "ui_up")
	if not is_zero_approx(swim):
		velocity.y = swim * SWIM_VELOCITY

	var direction := Input.get_axis("ui_left", "ui_right")
	var is_boosting = Input.is_action_pressed("shift")
	var speed = SPEED

	if is_boosting and not boosting:
		boosting = true
		boost_timer = BOOST_DELAY
		_add_shake(SHAKE_BOOST)

	if boosting and boost_timer > 0:
		boost_timer -= delta

	if boost_timer <= 0 and boosting:
		speed = BOOST

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

	velocity.z += current_flow
	move_and_slide()

	if global_position.y < -15.0:
		GameManager.take_damage(GameManager.MAX_HEALTH)

	var target_fov = BOOST_FOV if (boosting and boost_timer <= 0) else DEFAULT_FOV
	_camera.fov = lerp(_camera.fov, target_fov, delta * 5)


func set_flow(value: float) -> void:
	current_flow = value


func take_damage(amount: int) -> void:
	if invulnerable:
		return
	invulnerable = true
	invulnerable_timer = INVULNERABLE_TIME
	_animator.play_hurt()
	_visuals.flash_damage()
	_add_shake(SHAKE_DAMAGE)
	_start_hitstop()
	_spawn_burst(BURST_BUBBLES)
	GameManager.take_damage(amount)


func _add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, 1.0)


## Hit-stop: freeze the world for a beat when the turtle takes a hit.
##
## The deadline is wall-clock, not a countdown on a delta. That distinction is the
## whole bug this replaced: counting down `_hitstop -= get_physics_process_delta_time()`
## while also setting `Engine.time_scale = HITSTOP_SCALE` means the delta being
## consumed is already divided by HITSTOP_SCALE, so the 0.11 s of hit-stop took
## 0.11 / 0.04 = 2.75 s of real time. For those three seconds the entire game --
## turtle, hazards, particles, physics -- ran at 4% speed, which is what made a
## collision with a hazard read as the turtle being stuck and then slowly sinking.
##
## `Time.get_ticks_msec()` is unscaled, so the freeze now lasts as long as it says.
func _start_hitstop() -> void:
	if get_tree().paused:
		return
	_hitstop_until_ms = Time.get_ticks_msec() + int(HITSTOP_TIME * 1000.0)
	Engine.time_scale = HITSTOP_SCALE


func _update_hitstop() -> void:
	if _hitstop_until_ms == 0:
		return
	if Time.get_ticks_msec() < _hitstop_until_ms:
		Engine.time_scale = HITSTOP_SCALE
		return
	_hitstop_until_ms = 0
	Engine.time_scale = 1.0


## A fatal hit restarts the level from inside `take_damage`, so this node can be
## freed while the world is still frozen. `_ready` resets the scale on the way in,
## but leaving a live hit-stop with no owner would strand the game at 4% speed.
func _exit_tree() -> void:
	if _hitstop_until_ms != 0:
		_hitstop_until_ms = 0
		Engine.time_scale = 1.0


func _spawn_burst(kind: int) -> void:
	var burst := FEEDBACK_BURST.instantiate()
	burst.kind = kind
	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(burst)
	burst.global_position = global_position + Vector3(0, 0.35, 0)
