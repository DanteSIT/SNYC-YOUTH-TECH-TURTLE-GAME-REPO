extends Area3D

@export var damage := 10
@export var chase_speed := 3.6
@export var accel := 2.5
@export var activate_range := 22.0
@export var despawn_distance := 26.0

var _player: Node3D
var _active := false
var _vel := Vector3.ZERO
var _t := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = false
	_tint_model()


## Threat colouring lives here rather than in hard-coded meshes, so the body can
## be any model: whatever sits under Body/Model gets a red emissive override.
func _tint_model() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.25, 0.15)
	mat.roughness = 0.45
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.1, 0.05)
	mat.emission_energy_multiplier = 0.85
	for m in find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = mat


func _physics_process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	var to_player := _player.global_position - global_position
	to_player.y *= 0.5
	var dist := to_player.length()
	if not _active:
		if dist < activate_range:
			_active = true
			monitoring = true
		else:
			_idle(delta)
			return
	var dir := to_player.normalized() if dist > 0.01 else Vector3.FORWARD
	var target_v := dir * chase_speed
	_vel = _vel.lerp(target_v, minf(accel * delta, 1.0))
	global_position += _vel * delta
	var flat := Vector3(_vel.x, 0.0, _vel.z)
	if flat.length() > 0.1:
		rotation.y = atan2(flat.x, flat.z)
	_animate(delta)
	var behind := _player.global_position.z - global_position.z
	if absf(behind) > despawn_distance:
		queue_free()
		return
	# stay on the playfield plane: the turtle only ever moves in z and y.
	# (The old z clamp of +/-26 teleported chasers in the longer levels.)
	global_position.x = clampf(global_position.x, -0.6, 0.6)
	global_position.y = clampf(global_position.y, 0.7, 3.8)


func _idle(delta: float) -> void:
	$Body.rotation.y = sin(_t * 0.8) * 0.4
	$Body.rotation.x = sin(_t * 1.6) * 0.06
	global_position.y += sin(_t * 2.0) * 0.01 * delta * 60.0


func _animate(delta: float) -> void:
	$Body.rotation.x = sin(_t * 2.2) * 0.05
	$Body.rotation.y = sin(_t * 3.0) * 0.12
	$Body.rotation.z = sin(_t * 1.7) * 0.10


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
