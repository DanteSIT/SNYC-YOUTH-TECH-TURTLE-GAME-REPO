extends Control

func _ready() -> void:
	$ScoreLabel.text = "Score : %d    Jellyfish : %d" % [GameManager.score, GameManager.jellyfish]
	$RetryButton.pressed.connect(_on_retry_pressed)
	$MenuButton.pressed.connect(_on_menu_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Mark it handled first: the scene change below frees this node, and
		# get_viewport() is null afterwards.
		get_viewport().set_input_as_handled()
		_on_menu_pressed()


func _on_retry_pressed() -> void:
	GameManager.start_level(GameManager.current_level)

func _on_menu_pressed() -> void:
	GameManager.return_to_level_select()
