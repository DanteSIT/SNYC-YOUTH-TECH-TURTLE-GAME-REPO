extends SceneTree
## Checks the generated UI tones and that buttons are wired to them.
##
## Usage: godot --headless --path . --script res://tools/probe_ui_sound.gd

const SCENE := "res://scenes/ui/menu.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sound: Node = get_root().get_node("UISound")
	_expect("hover tone generated", sound._hover != null and _peak(sound._hover) > 100)
	_expect("click tone generated", sound._click != null and _peak(sound._click) > 100)

	var packed: PackedScene = load(SCENE)
	var menu: Node = packed.instantiate()
	get_root().add_child(menu)
	await process_frame
	await process_frame

	var button := menu.get_node("Menu/PlayButton") as Button
	_expect("button is wired", button.has_meta("ui_sound"))
	button.mouse_entered.emit()
	await process_frame
	_expect("hover picks the hover tone", _has_voice(sound, sound._hover))
	button.pressed.emit()
	await process_frame
	_expect("press picks the click tone", _has_voice(sound, sound._click))

	menu.queue_free()
	await process_frame
	print("UI SOUND %s" % ("OK" if _failures == 0 else "FAIL"))
	quit(1 if _failures else 0)


func _peak(stream: AudioStreamWAV) -> int:
	var data := stream.data
	var peak := 0
	for i in range(0, data.size(), 2):
		peak = maxi(peak, absi(data.decode_s16(i)))
	return peak


func _has_voice(sound: Node, stream: AudioStreamWAV) -> bool:
	for player in sound._players:
		if (player as AudioStreamPlayer).stream == stream:
			return true
	return false


func _expect(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %-38s %s" % [label, "ok" if ok else "FAIL"])
