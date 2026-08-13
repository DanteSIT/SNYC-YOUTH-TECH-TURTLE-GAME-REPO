extends Control

func _ready() -> void:
	for i in range(GameManager.LEVELS.size()):
		var btn := get_node("Grid/Level%d" % (i + 1)) as Button
		btn.disabled = i >= GameManager.levels_unlocked
		if btn.disabled:
			btn.text += "  (Locked)"
		btn.pressed.connect(_on_level_pressed.bind(i))
	$BackButton.pressed.connect(_on_back_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _on_level_pressed(index: int) -> void:
	GameManager.start_level(index)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/menu.tscn")
