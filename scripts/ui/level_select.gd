extends Control

func _ready() -> void:
	_build_grid()
	$BackButton.pressed.connect(_on_back_pressed)
	_build_god_mode_button()


func _build_grid() -> void:
	var grid := get_node("Grid") as GridContainer
	for child in grid.get_children():
		child.queue_free()
	for i in range(GameManager.LEVELS.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 60)
		btn.text = "Tutorial" if i == 0 else "Level %d" % i
		btn.disabled = i >= GameManager.levels_unlocked
		if btn.disabled:
			btn.text += "  (Locked)"
		btn.pressed.connect(_on_level_pressed.bind(i))
		grid.add_child(btn)


func _build_god_mode_button() -> void:
	var btn := Button.new()
	btn.text = "God Mode"
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = -220.0
	btn.offset_top = -70.0
	btn.offset_right = -20.0
	btn.offset_bottom = -30.0
	btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	btn.pressed.connect(_on_god_mode_pressed)
	add_child(btn)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _on_level_pressed(index: int) -> void:
	GameManager.start_level(index)

func _on_back_pressed() -> void:
	GameFlow.to_menu()

func _on_god_mode_pressed() -> void:
	GameManager.levels_unlocked = GameManager.LEVELS.size()
	_build_grid()
