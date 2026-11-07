extends SceneTree
## Checks every hazard carries the high-contrast warning marker and that it
## pulses, so the danger cue is not colour-only.
##
## Usage: godot --headless --path . --script res://tools/probe_hazard_cue.gd

const HAZARDS := [
	"res://scenes/objects/hazard.tscn",
	"res://scenes/objects/hazard_bottle.tscn",
	"res://scenes/objects/hazard_can.tscn",
	"res://scenes/objects/hazard_hook.tscn",
	"res://scenes/objects/hazard_net.tscn",
]

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for path in HAZARDS:
		var packed: PackedScene = load(path)
		var hazard: Node = packed.instantiate()
		get_root().add_child(hazard)
		await process_frame

		var marker := hazard.get_node_or_null("WarningMarker") as Label3D
		_expect("%s has a marker" % path.get_file(), marker != null)
		if marker != null:
			_expect("%s marker is a warning" % path.get_file(), marker.text == "!")
			_expect("%s marker faces the camera" % path.get_file(),
				marker.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
			_expect("%s marker sits above the litter" % path.get_file(),
				marker.position.y > 0.5)
			var before: float = marker.modulate.a
			hazard._process(0.3)
			_expect("%s marker pulses" % path.get_file(),
				not is_equal_approx(marker.modulate.a, before))
		hazard.queue_free()
		await process_frame

	print("HAZARD CUE %s" % ("OK" if _failures == 0 else "FAIL"))
	quit(1 if _failures else 0)


func _expect(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %-38s %s" % [label, "ok" if ok else "FAIL"])
