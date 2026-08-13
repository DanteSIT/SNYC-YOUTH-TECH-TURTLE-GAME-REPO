extends CharacterBody3D

const SPEED = 3
const JUMP_VELOCITY = 2
const SWIM_VELOCITY = 3
const BOOST = 4
const BOOST_DELAY = 0.2
const DEFAULT_FOV = 90.0
const BOOST_FOV = 110.0
const TILT_UP = -PI / 25
const TILT_DOWN = PI / 25
const INVULNERABLE_TIME = 1.0

var boosting := false
var boost_timer := 0.0
var invulnerable := false
var invulnerable_timer := 0.0

func _ready():
	$Odysse/AnimationPlayer.get_animation("IDLE").loop = true
	$Odysse/AnimationPlayer.get_animation("SWIMMING").loop = true
	$Odysse/AnimationPlayer.play("IDLE")

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

	if direction:
		velocity.z = -direction * speed
		$Odysse.rotation.y = (1 + direction) * PI / 2

		if boosting and boost_timer <= 0:
			if $Odysse/AnimationPlayer.current_animation != "SWIMMING":
				$Odysse/AnimationPlayer.play("SWIMMING")
			$Odysse/AnimationPlayer.speed_scale = 1.5
		elif $Odysse/AnimationPlayer.current_animation != "SWIMMING":
			$Odysse/AnimationPlayer.play("SWIMMING")
			$Odysse/AnimationPlayer.speed_scale = 1.0
	else:
		velocity.z = move_toward(velocity.z, 0, speed)
		boosting = false
		boost_timer = 0.0
		$Odysse/AnimationPlayer.speed_scale = 1.0
		if $Odysse/AnimationPlayer.current_animation != "IDLE":
			$Odysse/AnimationPlayer.play("IDLE")

	move_and_slide()

	if global_position.y < -15.0:
		GameManager.take_damage(GameManager.MAX_HEALTH)

	# Camera FOV
	var target_fov = BOOST_FOV if (boosting and boost_timer <= 0) else DEFAULT_FOV
	$Camera3D.fov = lerp($Camera3D.fov, target_fov, delta * 5)

	# Turtle tilt when jumping/falling
	var target_tilt = 0.0
	if velocity.y > 0:
		target_tilt = TILT_UP
	elif velocity.y < 0:
		target_tilt = TILT_DOWN
	$Odysse.rotation.x = lerp($Odysse.rotation.x, target_tilt, delta * 8)

func take_damage(amount: int) -> void:
	if invulnerable:
		return
	invulnerable = true
	invulnerable_timer = INVULNERABLE_TIME
	GameManager.take_damage(amount)
