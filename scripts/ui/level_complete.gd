extends Control

func _ready() -> void:
	var jelly: String = "%d / %d" % [GameManager.jellyfish, GameManager.level_jellyfish_total]
	var missed: int = GameManager.jellyfish_missed()
	$ScoreLabel.text = "Score : %d    Jellyfish : %s    Missed : %d\nTime : %s" % [
		GameManager.score, jelly, missed, GameManager.format_time(GameManager.level_time)]
	$NextButton.pressed.connect(_on_next_pressed)
	$MenuButton.pressed.connect(_on_menu_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_menu_pressed()
		get_viewport().set_input_as_handled()


func _on_next_pressed() -> void:
	GameManager.next_level()

func _on_menu_pressed() -> void:
	GameManager.return_to_level_select()
