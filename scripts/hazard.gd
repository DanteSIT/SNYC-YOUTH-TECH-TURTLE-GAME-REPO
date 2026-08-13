extends Area3D

@export var damage := 25
@export var patrol_end := Vector3.ZERO
@export_range(0.0, 10.0) var patrol_speed := 1.5

var _patrol_start: Vector3
var _patrol_dir := 1.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_patrol_start = global_position

func _physics_process(delta: float) -> void:
	if patrol_end == Vector3.ZERO:
		return
	var target := _patrol_start + patrol_end if _patrol_dir > 0.0 else _patrol_start
	var from := global_position
	var next := from.move_toward(target, patrol_speed * delta)
	global_position = next
	if from.distance_to(target) < 0.02:
		_patrol_dir *= -1.0

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
