extends Node3D

## Flashes the turtle red when it takes damage. The skin node is exported so a
## different model can be dropped in without hunting through the scene tree. If
## the path is missing, the first mesh under the player is used instead.

@export var skin_path: NodePath = ^"../Odysse/Armature_002/Skeleton3D/Turtle_LowPoly_Skin"
@export var flash_color := Color(1.0, 0.15, 0.1)
@export var flash_decay := 4.0

var _flash_mat: StandardMaterial3D
var _flash_energy := 0.0


func _ready() -> void:
	var skin := get_node_or_null(skin_path) as MeshInstance3D
	if skin == null:
		skin = _first_mesh()
	if skin == null:
		return
	var base := skin.get_surface_override_material(0)
	var material := (base.duplicate() if base else StandardMaterial3D.new()) as StandardMaterial3D
	material.emission_enabled = true
	material.emission = flash_color
	material.emission_energy_multiplier = 0.0
	skin.set_surface_override_material(0, material)
	_flash_mat = material


## Fallback for a swapped model: use the first mesh we can find.
func _first_mesh() -> MeshInstance3D:
	var owner := get_parent()
	if owner == null:
		return null
	for node in owner.find_children("*", "MeshInstance3D", true, false):
		return node as MeshInstance3D
	return null


func _process(delta: float) -> void:
	if _flash_mat == null:
		return
	if _flash_energy > 0.0:
		_flash_energy = maxf(_flash_energy - delta * flash_decay, 0.0)
		_flash_mat.emission_energy_multiplier = _flash_energy


func flash_damage() -> void:
	_flash_energy = 1.0
