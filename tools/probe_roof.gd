extends SceneTree
## Holds "up" and checks the turtle stays under the roof line.
##
## The hard ceiling collider is gone, replaced by a gentle downward push. This
## swims straight up for a few seconds and reports the highest point reached.
## Usage: godot --headless --path . --script res://tools/probe_roof.gd -- <scene>

const ROOF_LIMIT := 4.8


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = argv[0] if argv.size() > 0 else "res://scenes/levels/level_5.tscn"
	var packed: PackedScene = load(scene_path)
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	await physics_frame

	var turtle := world.get_node_or_null("Turtle/CharacterBody3D") as CharacterBody3D
	if turtle == null:
		printerr("no Turtle in ", scene_path)
		quit(1)
		return

	# Test in open water at mid-level, away from the start pipe.
	turtle.global_position = Vector3(0.0, 2.5, 0.0)
	turtle.velocity = Vector3.ZERO
	await physics_frame

	var top := turtle.global_position.y
	Input.action_press("ui_up")
	for _i in 300:
		await physics_frame
		top = maxf(top, turtle.global_position.y)
	Input.action_release("ui_up")

	print("ROOF top %.2f limit %.2f  %s" % [
		top, ROOF_LIMIT, "OK" if top <= ROOF_LIMIT else "FAIL"])
	quit(0 if top <= ROOF_LIMIT else 1)
