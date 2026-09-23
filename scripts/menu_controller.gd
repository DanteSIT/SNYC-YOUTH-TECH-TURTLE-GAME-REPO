extends Node

const MENU_SCRIPT := "res://scripts/ui/menu.gd"
const MENU_SCENE_PATH := "res://scenes/ui/menu.tscn"

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node.name == "Menu" and node.scene_file_path == MENU_SCENE_PATH and node.get_script() == null:
		node.set_script(load(MENU_SCRIPT))
