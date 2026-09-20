extends Node3D

@export var glow := false
@export var variant := -1

var _base_y := 0.0
var _t := 0.0
var _drift := 0.0
var _rng := RandomNumberGenerator.new()
var _tents: Array[MeshInstance3D] = []

const BLUE_TEX := preload("res://assets/textures/jelly_head_blue.png")
const ORANGE_TEX := preload("res://assets/textures/jelly_head_orange.png")


func _ready() -> void:
	_rng.randomize()
	_base_y = global_position.y
	_drift = _rng.randf_range(0.3, 0.8)
	for i in range(7):
		var t := get_node_or_null("Tent%d" % i) as MeshInstance3D
		if t:
			_tents.append(t)
	if variant < 0:
		variant = 0 if _rng.randf() < 0.55 else 1
	_apply_variant()


func _apply_variant() -> void:
	var is_orange := variant == 1
	var dome_tex: Texture2D = ORANGE_TEX if is_orange else BLUE_TEX
	var tint := _rng.randf_range(0.8, 1.15)
	var glow_c := Color(1.0, 0.55, 0.25) if is_orange else Color(0.4, 0.85, 1.0)
	var dome_mat: StandardMaterial3D = (($Dome.mesh as Mesh).material as StandardMaterial3D).duplicate()
	dome_mat.albedo_texture = dome_tex
	dome_mat.albedo_color = Color(1, 1, 1, 1) * Color(tint, tint, tint, 0.92)
	dome_mat.emission = glow_c
	dome_mat.emission_energy_multiplier = 0.55 * tint
	$Dome.material_override = dome_mat

	var inner_mat: StandardMaterial3D = (($Inner.mesh as Mesh).material as StandardMaterial3D).duplicate()
	inner_mat.albedo_color = Color(1, 1, 1, 1) * Color(tint, tint, tint, 0.9)
	inner_mat.emission = glow_c
	inner_mat.emission_energy_multiplier = 0.5
	$Inner.material_override = inner_mat

	for t in _tents:
		var tm: StandardMaterial3D = dome_mat.duplicate()
		tm.emission_enabled = true
		tm.emission = glow_c
		tm.emission_energy_multiplier = 0.6
		t.material_override = tm

	$GlowLight.light_color = glow_c
	$GlowLight.visible = glow
	$GlowLight.light_energy = 1.1 if glow else 0.0


func _process(delta: float) -> void:
	_t += delta
	global_position.y = _base_y + sin(_t * 0.7) * 0.22
	global_position.x += sin(_t * 0.3 + _drift) * _drift * delta * 0.35
	rotation.y += delta * 0.3
	for i in _tents.size():
		var th: float = TAU * i / 7.0
		var sway := sin(_t * 1.4 + i) * 0.06
		var tilt := 0.12 + sway
		_tents[i].rotation.z = cos(th) * tilt
		_tents[i].rotation.x = -sin(th) * tilt
		_tents[i].position.y = -0.3 + sin(_t * 1.7 + i * 0.8) * 0.04
