extends Node3D

## Ambient decorative fish for the CC0 Kenney fish models: cruises along the
## corridor with a gentle bob and roll, wrapping around a short span so it
## never swims off into the void.

@export var speed := 1.4
@export var bob_amplitude := 0.22
@export var bob_speed := 1.6
@export var roll_amount := 0.18
## The Kenney fish model's head points along LOCAL -X (its Z-width tapers to
## the tail at +X), so the yaw offset that aims it at -Z is 270 degrees.
## With 90 it swam tail-first.
@export var forward := -1.0
@export var yaw_offset_deg := 270.0
@export var span := 10.0
@export var phase := 0.0

var _t := 0.0
var _origin := Vector3.ZERO
var _base_yaw := 0.0


func _ready() -> void:
	_origin = global_position
	_t = phase
	_base_yaw = deg_to_rad(yaw_offset_deg)


func _process(delta: float) -> void:
	_t += delta
	global_position.z += forward * speed * delta
	if absf(global_position.z - _origin.z) > span:
		global_position.z = _origin.z - forward * span
	global_position.y = _origin.y + sin(_t * bob_speed) * bob_amplitude
	rotation.y = _base_yaw + (0.0 if forward < 0.0 else PI)
	rotation.z = sin(_t * bob_speed * 1.3) * roll_amount
