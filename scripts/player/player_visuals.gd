extends Node3D

const SKIN_PATH := "../Odysse/Armature_002/Skeleton3D/Turtle_LowPoly_Skin"
const FLASH_COLOR := Color(1.0, 0.15, 0.1)
const FLASH_DECAY := 4.0

var _flash_mat: StandardMaterial3D
var _flash_energy := 0.0


func _ready() -> void:
	var skin := get_node_or_null(SKIN_PATH) as MeshInstance3D
	if skin == null:
		return
	var base := skin.get_surface_override_material(0)
	var material := (base.duplicate() if base else StandardMaterial3D.new()) as StandardMaterial3D
	material.emission_enabled = true
	material.emission = FLASH_COLOR
	material.emission_energy_multiplier = 0.0
	skin.set_surface_override_material(0, material)
	_flash_mat = material


func _process(delta: float) -> void:
	if _flash_mat == null:
		return
	if _flash_energy > 0.0:
		_flash_energy = maxf(_flash_energy - delta * FLASH_DECAY, 0.0)
		_flash_mat.emission_energy_multiplier = _flash_energy


func flash_damage() -> void:
	_flash_energy = 1.0