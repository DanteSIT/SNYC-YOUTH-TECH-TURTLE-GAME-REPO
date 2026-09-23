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

@onready var _camera: Camera3D = $Camera3D
@onready var _animator: Node3D = $PlayerAnimator
@onready var _visuals: Node3D = $PlayerVisuals


func _ready() -> void:
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
	_camera.global_position = _cam_anchor + global_basis * rest_origin
	_camera.look_at(global_position + Vector3(0, 0.3, 0), Vector3.UP)


func _physics_process(delta: float) -> void:
	if invulnerable:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0:
			invulnerable = false

	velocity.x = 0

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept"):
		velocity.y = JUMP_VELOCITY

	var swim := Input.get_axis("ui_up", "ui_down")
	if not is_zero_approx(swim):
		velocity.y = swim * SWIM_VELOCITY

	var direction := Input.get_axis("ui_left", "ui_right")
	var is_boosting = Input.is_action_pressed("shift")
	var speed = SPEED

	if is_boosting and not boosting:
		boosting = true
		boost_timer = BOOST_DELAY

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
	else:
		velocity.z = move_toward(velocity.z, 0, speed)
		boosting = false
		boost_timer = 0.0
		if _swim_sound.playing:
			_swim_sound.stop()

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
	GameManager.take_damage(amount)
