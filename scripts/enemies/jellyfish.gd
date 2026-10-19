extends Node3D
## Ambient decorative jellyfish ("Fauna"). Rebuilt to swim the real imported
## jeLLyfiSH model instead of the old procedural dome+tentacle rig, so it matches
## the collectables. A blue/orange translucent emissive variant + slow drift/bob.

@export var glow := false
@export var variant := -1   # -1 = random, 0 = blue, 1 = orange

const BLUE_TINT := Color(0.52, 0.82, 1.0)
const ORANGE_TINT := Color(1.0, 0.72, 0.42)
const BLUE_GLOW := Color(0.4, 0.85, 1.0)
const ORANGE_GLOW := Color(1.0, 0.55, 0.25)

var _base_y := 0.0
var _t := 0.0
var _drift := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_base_y = global_position.y
	_drift = _rng.randf_range(0.3, 0.8)
	if variant < 0:
		variant = 0 if _rng.randf() < 0.55 else 1
	_apply_variant()


func _apply_variant() -> void:
	var is_orange := variant == 1
	var tint: Color = ORANGE_TINT if is_orange else BLUE_TINT
	var glow_c: Color = ORANGE_GLOW if is_orange else BLUE_GLOW
	var bright := _rng.randf_range(0.85, 1.15)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(tint.r * bright, tint.g * bright, tint.b * bright, 0.55)
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = glow_c
	mat.emission_energy_multiplier = 0.65

	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = mat

	var light := get_node_or_null("GlowLight") as OmniLight3D
	if light != null:
		light.light_color = glow_c
		light.visible = glow
		light.light_energy = 1.1 if glow else 0.0


func _process(delta: float) -> void:
	_t += delta
	global_position.y = _base_y + sin(_t * 0.7) * 0.22
	global_position.x += sin(_t * 0.3 + _drift) * _drift * delta * 0.35
	rotation.y += delta * 0.3
