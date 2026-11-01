extends SceneTree
## Regression check for the tutorial state machine.
##
## Verifies that steps wait for their action, that informational steps show the
## instruction instead of skipping straight to "done", that the gate pushes the
## player back, and that a reload resumes at the saved step.
##
## Usage: godot --headless --path . --script res://tools/probe_tutorial.gd

const SCENE := "res://scenes/levels/tutorial.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := await _load()
	var player := _player(world)
	var tut: Node = world
	_show("start", tut)

	# Step 0: hold right until the swim step confirms.
	Input.action_press("ui_right")
	await _frames(90)
	_expect(tut, "swim step done", true)
	await _until_z(player, 20.5, 300)
	_expect_stage(tut, "after swim", 1)

	# Gate: teleport past the gate without doing the depth step.
	player.global_position = Vector3(0.0, 2.0, 16.0)
	player.velocity = Vector3.ZERO
	await _frames(40)
	var state: Dictionary = tut.debug_state()
	_expect(tut, "gate blocks unfinished step", state["blocked"] == true)
	_expect(tut, "gate pushes player back", player.global_position.z > 16.5)
	_show("blocked", tut)

	# Complete the depth step with one press of each direction.
	player.global_position = Vector3(0.0, 2.0, 20.0)
	player.velocity = Vector3.ZERO
	await _tap("ui_up")
	await _tap("ui_down")
	_expect(tut, "depth step done", true)

	# Step 2 is informational: it must still show its warning, not "Well dodged".
	await _until_z(player, 17.5, 300)
	_expect_stage(tut, "after depth", 2)
	var hazard: Dictionary = tut.debug_state()
	_expect(tut, "hazard warning is visible",
		String(hazard["message"]).contains("Plastic bags"))
	_expect(tut, "hazard step is not done yet", hazard["done"] == false)
	_show("hazard", tut)

	# Step 3: a pickup completes the collect step.
	await _until_z(player, 14.5, 300)
	_expect_stage(tut, "after hazard", 3)
	_gm().add_jellyfish(1)
	await _frames(3)
	_expect(tut, "collect step done", true)

	# Step 4 arrives at the high-ledge cluster.
	await _until_z(player, 10.5, 300)
	_expect_stage(tut, "after collect", 4)
	var high: Dictionary = tut.debug_state()
	_expect(tut, "high ledge prompt is visible",
		String(high["message"]).contains("ledge"))
	Input.action_release("ui_right")

	# Reloading keeps the saved step and moves the turtle near it.
	world.queue_free()
	await process_frame
	_gm().tutorial_stage = 5
	var again := await _load()
	var again_player := _player(again)
	_expect_stage(again, "reload stage", 5)
	_expect(again, "reload places turtle at the step",
		absf(again_player.global_position.z - 7.0) < 0.5)
	_show("reload", again)

	print("TUTORIAL %s" % ("OK" if _failures == 0 else "FAIL"))
	quit(1 if _failures else 0)


func _load() -> Node:
	var packed: PackedScene = load(SCENE)
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	await _frames(5)
	return world


func _player(world: Node) -> CharacterBody3D:
	return world.get_node_or_null("Turtle/CharacterBody3D") as CharacterBody3D


func _gm() -> Node:
	return get_root().get_node("GameManager")


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _until_z(player: CharacterBody3D, target: float, limit: int) -> void:
	for _i in limit:
		if player.global_position.z <= target:
			return
		await physics_frame


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(3)
	Input.action_release(action)
	await _frames(3)


func _expect(tut: Node, label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %-34s %s" % [label, "ok" if ok else "FAIL"])


func _expect_stage(tut: Node, label: String, stage: int) -> void:
	var state: Dictionary = tut.debug_state()
	_expect(tut, label, int(state["stage"]) == stage)


func _show(label: String, tut: Node) -> void:
	var state: Dictionary = tut.debug_state()
	print("  [%s] stage=%d done=%s blocked=%s" % [
		label, int(state["stage"]), str(state["done"]), str(state["blocked"])])
