extends Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$SettingsUI.back_pressed.connect(_on_back_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _on_back_pressed() -> void:
	GameFlow.to_menu()
