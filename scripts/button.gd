extends Button

func _ready():
	button_up.connect(_on_pressed)

func _on_pressed():
	get_tree().change_scene_to_file("res://world.tscn")
