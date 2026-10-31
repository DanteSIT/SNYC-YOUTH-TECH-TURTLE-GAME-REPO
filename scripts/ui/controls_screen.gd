extends Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$ControlsUI.back_pressed.connect(_on_back_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Mark it handled first: the scene change below frees this node, and
		# get_viewport() is null afterwards.
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _on_back_pressed() -> void:
	GameFlow.to_menu()
