extends Node3D

@export var drift_speed := 0.14
@export var drift_amount := 0.25

var _t := 0.0
var _base_positions: Array[Vector3] = []

func _ready() -> void:
	for c in get_children():
		if c is MeshInstance3D:
			_base_positions.append(c.position)

func _process(delta: float) -> void:
	_t += delta
	for i in get_child_count():
		var c := get_child(i)
		if c is MeshInstance3D and i < _base_positions.size():
			var base: Vector3 = _base_positions[i]
			c.position = Vector3(
				base.x + sin(_t * drift_speed * 0.8 + i * 2.1) * drift_amount,
				base.y,
				base.z + sin(_t * drift_speed * 1.3 + i * 1.4) * drift_amount * 0.6)
