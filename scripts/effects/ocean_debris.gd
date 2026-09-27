extends Node3D
## ocean_debris.gd — flotsam pockets that churn as the turtle swims by.
##
## Attached to the OceanParticles root in scenes/effects/ocean_particles.tscn.
## Each pocket carries a Debris field (tumbling litter) and a Bobbers line
## (buoyant pieces bobbing along the corridor's upper arc).  While the player
## is inside PROXIMITY both emitters ramp a turbulence field and a velocity
## kick (the litter swirls in the turtle's wake) and then settle back to a
## lazy drift once they pass.
##
## Every pocket duplicates both particle materials at _ready so pockets in the
## same level never share (and cross-trigger) one another.

const PROXIMITY := 6.0        # stir radius around the pocket origin
const STIR_RATE := 4.0        # how fast the churn ramps in (0 -> 1)
const DECAY_RATE := 2.2       # how fast it settles after the turtle leaves
const MAX_TURBULENCE := 3.5   # turbulence_noise_strength at full stir
const MIN_TURB_SPEED := 1.5   # noise scroll speed, calm
const MAX_TURB_SPEED := 7.0   # noise scroll speed, stirred
const MAX_VELOCITY_KICK := 1.6  # multiplier added to initial velocity when stirred

const _EMITTERS := ["Debris", "Bobbers"]

var _pairs: Array = []        # of [ParticleProcessMaterial, vel_min, vel_max]
var _stir := 0.0
var _player: Node3D


func _ready() -> void:
	for name in _EMITTERS:
		var node := get_node_or_null(name) as GPUParticles3D
		if node == null:
			continue
		# Per-instance material so pockets never share churn state.
		var mat := (node.process_material as ParticleProcessMaterial).duplicate()
		node.process_material = mat
		_pairs.append([mat, mat.initial_velocity_min, mat.initial_velocity_max])
	if _pairs.is_empty():
		set_process(false)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player != null:
		var d := global_position.distance_to(_player.global_position)
		if d < PROXIMITY:
			_stir = minf(_stir + delta * STIR_RATE, 1.0)
		else:
			_stir = maxf(_stir - delta * DECAY_RATE, 0.0)
	else:
		_stir = maxf(_stir - delta * DECAY_RATE, 0.0)
	_apply()


func _apply() -> void:
	var s := _stir
	for pair in _pairs:
		var mat: ParticleProcessMaterial = pair[0]
		mat.turbulence_enabled = s > 0.02
		mat.turbulence_noise_strength = MAX_TURBULENCE * s
		mat.turbulence_noise_speed = Vector3.ONE * lerpf(MIN_TURB_SPEED, MAX_TURB_SPEED, s)
		# Velocity kick: only affects newly spawned litter, so it reads as a
		# gradual stirring-up rather than a teleport; the field handles the rest.
		mat.initial_velocity_min = pair[1] * (1.0 + MAX_VELOCITY_KICK * s)
		mat.initial_velocity_max = pair[2] * (1.0 + MAX_VELOCITY_KICK * s)