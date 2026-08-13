extends CharacterBody3D

func _ready():
	$Odysse/AnimationPlayer.get_animation("IDLE").loop = true
	$Odysse/AnimationPlayer.play("IDLE")
	
