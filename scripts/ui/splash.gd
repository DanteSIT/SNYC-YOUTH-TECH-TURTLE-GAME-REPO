extends Control

const MENU_SCENE := "res://scenes/ui/menu.tscn"
const MIN_DURATION := 2.0

var _elapsed := 0.0
var _menu: PackedScene


func _ready() -> void:
	ResourceLoader.load_threaded_request(MENU_SCENE)


func _process(delta: float) -> void:
	_elapsed += delta
	$Bar.value = clampi(int(_elapsed / MIN_DURATION * 100.0), 0, 100)
	if _menu == null:
		var status: int = ResourceLoader.load_threaded_get_status(MENU_SCENE)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_menu = ResourceLoader.load_threaded_get(MENU_SCENE)
	if _menu != null and _elapsed >= MIN_DURATION:
		GameFlow.change_scene_packed(_menu)
