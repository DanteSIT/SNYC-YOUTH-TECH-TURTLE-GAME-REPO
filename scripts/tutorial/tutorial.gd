extends Node3D

const PANEL_BG := Color(0.04, 0.14, 0.22, 0.88)
const PANEL_DONE_BG := Color(0.03, 0.3, 0.22, 0.9)
const TEXT_COLOR := Color(0.88, 0.96, 1.0, 1.0)
const DONE_COLOR := Color(0.62, 1.0, 0.75, 1.0)
const ARROW_COLOR := Color(1.0, 0.85, 0.35, 0.95)

const STAGES: Array[Dictionary] = [
	{
		"z": 13.5,
		"msg": "Welcome! Hold  RIGHT  or  D  to swim forward.",
		"done": "Good! Keep swimming toward the light.",
		"cond": "swim",
		"target": Vector3(0, 0.7, 12.0),
	},
	{
		"z": 9.5,
		"msg": "Press  UP / W  or  DOWN / S  to swim up and down.",
		"done": "You control your depth now.",
		"cond": "vertical",
		"target": Vector3(0, 2.3, 8.0),
	},
	{
		"z": 5.5,
		"msg": "Hold  SHIFT  while swimming to BOOST!",
		"done": "Fast! That's your boost.",
		"cond": "boost",
		"target": Vector3(0, 1.4, 4.0),
	},
	{
		"z": 1.0,
		"msg": "Collect the glowing jellyfish for points.",
		"done": "Nice catch!",
		"cond": "collect",
		"target": Vector3(0, 1.5, 0.0),
	},
	{
		"z": -6.0,
		"msg": "Watch out! Floating trash is harmful. Dodge it!",
		"done": "",
		"cond": "none",
		"target": Vector3(0, 0.7, -3.0),
	},
	{
		"z": -17.0,
		"msg": "Almost there! Swim through the golden gate to finish.",
		"done": "",
		"cond": "none",
		"target": Vector3(0, 1.5, -17.0),
	},
]

var _player: CharacterBody3D
var _panel: PanelContainer
var _label: Label
var _sub_label: Label
var _arrow: Polygon2D
var _stage := 0
var _ready_flags: Dictionary = {}
var _swim_time := 0.0
var _boost_time := 0.0
var _vertical_presses := 0
var _jelly_seen := 0


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_jelly_seen = GameManager.jellyfish
	GameManager.jellyfish_changed.connect(_on_jelly_changed)
	_build_hud()
	_update_panel()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -300.0
	_panel.offset_right = 300.0
	_panel.offset_top = 12.0
	_panel.offset_bottom = 96.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(_panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(box)

	_label = Label.new()
	_label.text = ""
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(_label)

	_sub_label = Label.new()
	_sub_label.text = ""
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.add_theme_font_size_override("font_size", 16)
	_sub_label.add_theme_color_override("font_color", DONE_COLOR)
	box.add_child(_sub_label)

	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([
		Vector2(0, -18),
		Vector2(-12, 10),
		Vector2(12, 10),
	])
	_arrow.color = ARROW_COLOR
	layer.add_child(_arrow)


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		return

	while _stage + 1 < STAGES.size() and _player.global_position.z < STAGES[_stage + 1]["z"]:
		_stage += 1
	_check_condition(delta)
	_update_panel()
	_update_arrow()


func _check_condition(delta: float) -> void:
	if _ready_flags.get(_stage, false):
		return
	var cond: String = STAGES[_stage]["cond"]
	match cond:
		"swim":
			if Input.is_action_pressed("ui_right"):
				_swim_time += delta
				if _swim_time >= 0.7:
					_ready_flags[_stage] = true
		"vertical":
			if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"):
				_vertical_presses += 1
				if _vertical_presses >= 2:
					_ready_flags[_stage] = true
		"boost":
			if Input.is_action_pressed("shift"):
				_boost_time += delta
				if _boost_time >= 0.7:
					_ready_flags[_stage] = true
		"collect":
			if GameManager.jellyfish > _jelly_seen:
				_ready_flags[_stage] = true
		"none":
			_ready_flags[_stage] = true


func _update_panel() -> void:
	var done: bool = _ready_flags.get(_stage, false)
	var stage: Dictionary = STAGES[_stage]
	_label.text = stage["done"] if done else stage["msg"]
	var sb: StyleBoxFlat = _panel.get_theme_stylebox("panel")
	if done:
		_sub_label.text = "✓"
		sb.bg_color = PANEL_DONE_BG
	else:
		_sub_label.text = ""
		sb.bg_color = PANEL_BG


func _update_arrow() -> void:
	var cam: Camera3D = _player.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		_arrow.visible = false
		return
	var from := cam.unproject_position(_player.global_position)
	var to := cam.unproject_position(STAGES[_stage]["target"])
	var dir := to - from
	if dir.length() < 10.0:
		_arrow.visible = false
		return
	var pos := from + dir.normalized() * 120.0
	var size: Vector2 = cam.get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 34.0, size.x - 34.0)
	pos.y = clampf(pos.y, 34.0, size.y - 34.0)
	_arrow.visible = true
	_arrow.position = pos
	_arrow.rotation = dir.angle()


func _on_jelly_changed(value: int) -> void:
	if value > _jelly_seen:
		_ready_flags[3] = true
