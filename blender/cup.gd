extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready():
	$Cylinder.get_animation("new_animation").loop = true
