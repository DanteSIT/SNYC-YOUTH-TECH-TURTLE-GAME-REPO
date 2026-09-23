extends Node3D

@export var speed := 3.2
@export var damage := 25
@export var chase_radius := 50.0

var _player: Node3D


func _ready() -> void:
	$Area3D.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var player := _get_player()
	if player == null:
		return
	var to_player := player.global_position - global_position
	if to_player.length() > chase_radius:
		return
	var dir := to_player.normalized()
	dir.y *= 0.3
	dir = dir.normalized()
	global_position += dir * speed * delta
	_face_player(dir)


func _get_player() -> Node3D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	return _player


func _face_player(dir: Vector3) -> void:
	var flat := Vector2(dir.x, dir.z)
	if flat.length() > 0.01:
		rotation.y = atan2(-flat.x, -flat.y)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
