extends Node

## Optional larger text for menus and result screens.
##
## The in-level HUD keeps its own fixed layout, so it is deliberately skipped:
## its labels are already larger than the menu text and live inside a CanvasLayer.
## Controls added after a scale change pick the current scale up automatically.

const SAVE_PATH := "user://accessibility.cfg"
const TEXT_NAMES: Array[String] = ["Normal", "Large"]
const TEXT_SCALES: Array[float] = [1.0, 1.15]

var text_scale_index := 0

## Overridable so tools can exercise save/load without touching the real file.
var save_path := SAVE_PATH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	get_tree().node_added.connect(_on_node_added)
	_apply_existing.call_deferred(get_tree().root)


func get_text_names() -> Array[String]:
	return TEXT_NAMES


func get_text_scale_index() -> int:
	return text_scale_index


func text_scale() -> float:
	return TEXT_SCALES[text_scale_index]


func set_text_scale(index: int) -> void:
	text_scale_index = clampi(index, 0, TEXT_SCALES.size() - 1)
	save_settings()
	_apply_existing(get_tree().root)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	text_scale_index = clampi(
		int(cfg.get_value("accessibility", "text_scale", 0)), 0, TEXT_SCALES.size() - 1)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("accessibility", "text_scale", text_scale_index)
	cfg.save(save_path)


func _on_node_added(node: Node) -> void:
	if node is Label or node is Button or node is RichTextLabel:
		_apply.call_deferred(node)


func _apply_existing(node: Node) -> void:
	if node is Label or node is Button or node is RichTextLabel:
		_apply(node)
	for child in node.get_children():
		_apply_existing(child)


func _apply(control: Control) -> void:
	if not is_instance_valid(control) or _inside_canvas_layer(control):
		return

	# Labels that carry their own LabelSettings ignore theme overrides, so their
	# font size has to be scaled on a private copy of the settings.
	if control is Label and (control as Label).label_settings != null:
		var label := control as Label
		var settings := label.label_settings
		if not settings.has_meta("ui_base_font_size"):
			settings = settings.duplicate()
			label.label_settings = settings
			settings.set_meta("ui_base_font_size", settings.font_size)
		var base: int = int(settings.get_meta("ui_base_font_size"))
		settings.font_size = maxi(8, int(round(base * text_scale())))
		return

	var base_size: float
	if control.has_meta("ui_base_font_size"):
		base_size = float(control.get_meta("ui_base_font_size"))
	else:
		base_size = control.get_theme_font_size("font_size")
		if base_size <= 0.0:
			return
		control.set_meta("ui_base_font_size", base_size)
	control.add_theme_font_size_override("font_size",
		maxi(8, int(round(base_size * text_scale()))))


func _inside_canvas_layer(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent is CanvasLayer:
			return true
		parent = parent.get_parent()
	return false
