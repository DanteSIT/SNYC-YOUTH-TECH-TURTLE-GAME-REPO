extends Area3D

@export var damage := 45
@export var advance_speed := 3.6
@export var spawn_delay := 3.0
@export var spawn_distance := 12.0
@export var push_flow := 0.65
@export var push_range := 5.0
@export var swim_speed := 3.0
## How far the player must swim away from the start before the boss appears
## behind them. Stops it materialising while they are still in the pipe.
@export var trigger_distance := 14.0

var _t := 0.0
var _player: Node3D
var _spawned := false
var _spawn_timer := 0.0
var _start_z := 0.0
var _has_start := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Body.visible = false
	monitoring = false

func _physics_process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if not _spawned:
		if _player != null:
			if not _has_start:
				_start_z = _player.global_position.z
				_has_start = true
			_spawn_timer += delta
			var travelled := _start_z - _player.global_position.z
			if _spawn_timer >= spawn_delay and travelled >= trigger_distance:
				_spawn_behind_player()
		return
	if _player != null:
		var target: Vector3 = _player.global_position
		var to_player: Vector3 = target - global_position
		to_player.y = 1.0
		var dist := to_player.length()
		var dir := to_player.normalized() if dist > 0.001 else Vector3.FORWARD
		global_position += dir * advance_speed * delta
		global_position.y = lerpf(global_position.y, target.y, 2.5 * delta)
		# Point the model's HEAD at the player, which is local +Z, NOT Godot's
		# usual -Z. zshark.glb faces +Z: its caudal fin is a tall laterally thin
		# plate at local z = -3.9 (slab aspect 13.1 against 5.3 for the next), so
		# the head is at the +Z end. tools/probe_boss_facing.gd measures this from
		# the geometry and fails if the two disagree.
		#
		# There used to be a "+ PI" here with a matching 180 degree yaw baked into
		# Body's transform, so the two cancelled on paper. In practice the bake did
		# nothing: the swim wobble further down assigns $Body.rotation.y outright
		# every physics frame, discarding whatever yaw the scene authored, so the
		# shark swam tail-first the whole time. Do not try to correct the facing in
		# the .tscn -- the wobble will eat it. Change it here.
		rotation.y = lerp_angle(rotation.y, atan2(to_player.x, to_player.z), 4.0 * delta)
		if _player.has_method("set_flow"):
			_player.set_flow(push_flow if dist < push_range else 0.0)
	# the playfield is the plane x = 0; levels run to +/-116 in z so there is no
	# z clamp (the old +/-70 one yanked the boss sideways on long levels).
	global_position.x = clampf(global_position.x, -0.6, 0.6)
	$Body.rotation.y = sin(_t * swim_speed) * 0.15
	$Body.position.y = sin(_t * 1.4) * 0.06

func _spawn_behind_player() -> void:
	_spawned = true
	var back: Vector3 = _player.global_basis.z
	var spawn_pos: Vector3 = _player.global_position + back * spawn_distance
	spawn_pos.x = 0.0
	global_position = spawn_pos
	rotation.y = atan2(_player.global_position.x - spawn_pos.x, _player.global_position.z - spawn_pos.z)
	$Body.visible = true
	monitoring = true

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
