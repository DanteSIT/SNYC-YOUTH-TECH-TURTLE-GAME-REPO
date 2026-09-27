extends SceneTree
## Throwaway: is a node actually inside the camera's view when shot.gd captures?
##
## screenshots/09_shark_boss.png uses spec "hold=on,turtle=0,0.8,20,spawn=Boss,
## frames=150". shot.gd only reports err=0, which says the render happened, not
## that the subject is in it. The player camera sits at x = +3.576 looking along
## -X, so anything offset from the turtle along Z -- which is exactly how a boss
## spawns, 12 m behind the player -- is sideways in screen space, not ahead, and
## is easily outside the frustum. That is the same trap as the seabed skirt on
## the far edge. So: replicate the shot's setup and ask the camera directly.
##
## Usage:
##   godot --headless --path . --script res://tools/diag_shot_contains.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/levels/level_10.tscn")
	var world: Node = packed.instantiate()
	get_root().add_child(world)

	# Both can be nested -- the level root is a holder, not a plain list of
	# actors -- so search the whole tree rather than only the top level.
	var turtle: Node3D = world.find_child("Turtle", true, false) as Node3D
	if turtle == null:
		for n: Node in world.find_children("*", "Node3D", true, false):
			if n.is_in_group("player"):
				turtle = n
				break
	var boss: Node3D = world.find_child("Boss", true, false) as Node3D
	if turtle == null or boss == null:
		printerr("DIAG could not find turtle or Boss")
		quit(1)
		return

	for _i in 4:
		await process_frame
	turtle.global_position = Vector3(0.0, 0.8, 20.0)
	for _i in 4:
		await process_frame
	boss.call("_spawn_behind_player")

	# Mirror shot.gd's freecam override, driven by the same user args, so what is
	# checked here is the framing that will actually be captured. The turtle has
	# to stop processing first: player_controller.gd rewrites the camera's global
	# position every _process, so a camera placed here would be dragged straight
	# back to the player and the framing checked would not be the framing shot.
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var want_cam: PackedFloat64Array = _vec_arg(args, "cam")
	var want_look: PackedFloat64Array = _vec_arg(args, "look")
	var freecam: bool = want_cam.size() == 3
	if freecam:
		turtle.process_mode = Node.PROCESS_MODE_DISABLED

	var frames: int = _int_arg(args, "frames", 150)
	for _i in frames:
		await process_frame

	var body: Node3D = boss.get_node_or_null("Body") as Node3D
	# The camera is Turtle/CharacterBody3D/Camera3D (scenes/player/turtle.tscn),
	# not a level child, so look for it under the turtle rather than assuming.
	var cam: Camera3D = turtle.find_child("Camera3D", true, false) as Camera3D
	if cam == null:
		var found: Array[Node] = world.find_children("*", "Camera3D", true, false)
		printerr("DIAG no camera under the turtle; scene has %d: %s" % [
			found.size(), found.map(func(n: Node) -> String: return str(n.get_path()))])
		quit(1)
		return
	if freecam:
		cam.current = true
		cam.global_position = Vector3(want_cam[0], want_cam[1], want_cam[2])
		var target := Vector3.ZERO
		if want_look.size() == 3:
			target = Vector3(want_look[0], want_look[1], want_look[2])
		cam.look_at(target, Vector3.UP)
		if body == null:
			printerr("DIAG the boss has no Body child")
			quit(1)
			return

	print("")
	print("boss node pos      ", (boss as Node3D).global_position)
	print("body visible       ", body.visible)
	print("player pos         ", turtle.global_position)
	print("camera pos         ", cam.global_position, "  looking ", -cam.global_basis.z)
	var vp_size: Vector2 = cam.get_viewport().get_visible_rect().size
	print("camera fov         %.1f  near %.2f  far %.1f  size %dx%d" % [
		cam.fov, cam.near, cam.far, int(vp_size.x), int(vp_size.y)])

	# World-space AABB of every mesh under the Body.
	var box := AABB()
	var first := true
	var meshes: Array[Node] = []
	_collect_meshes(body, meshes)
	var hidden := 0
	for m: Node in meshes:
		if not (m as VisualInstance3D).visible:
			hidden += 1
			continue
		var a: AABB = ((m as MeshInstance3D).mesh.get_aabb() as AABB).abs()
		var w: AABB = (m as Node3D).global_transform * a
		if first:
			box = w
			first = false
		else:
			box = box.merge(w)
	print("mesh nodes         %d (%d not visible)" % [meshes.size(), hidden])
	print("body world AABB    ", box)

	var centre: Vector3 = box.get_center()
	print("")
	print("AABB centre in frustum: %s" % str(cam.is_position_in_frustum(centre))
		+ "   (%.2f m from camera)" % centre.distance_to(cam.global_position))
	var inside := 0
	var total := 0
	for i: int in range(3):
		for j: int in range(3):
			for k: int in range(3):
				var corner := Vector3(
					box.position.x if i == 0 else box.end.x,
					box.position.y if j == 0 else box.end.y,
					box.position.z if k == 0 else box.end.z)
				total += 1
				if cam.is_position_in_frustum(corner):
					inside += 1
	print("AABB corners in frustum: %d/%d" % [inside, total])

	# Distance from the view axis, which is what decides whether a sideways
	# offset is inside the horizontal FOV.
	var to_centre: Vector3 = centre - cam.global_position
	var axis: Vector3 = (-cam.global_basis.z).normalized()
	var side: Vector3 = cam.global_basis.x.normalized()
	var along: float = to_centre.dot(axis)
	var across: float = to_centre.dot(side)
	var half_w: float = absf(along) * tan(deg_to_rad(cam.fov) * 0.5) \
		* (vp_size.x / vp_size.y)
	print("centre %.1f m ahead, %.1f m to the side, frustum half-width there %.1f m -> %s" % [
		along, across, half_w, "IN VIEW" if absf(across) < half_w else "OUT OF VIEW"])
	quit()


func _collect_cams(from: Node, out: Camera3D) -> void:
	# Do not require current: headless has no render target, so a camera may
	# never be flagged current even though its transform is perfectly good and
	# is all this check needs.
	if from is Camera3D and out == null:
		out = from as Camera3D
	for c: Node in from.get_children():
		_collect_cams(c, out)


func _int_arg(args: PackedStringArray, key: String, fallback: int) -> int:
	var re := RegEx.new()
	re.compile("(?i)\\b%s=(\\d+)" % key)
	var m: RegExMatch = re.search(" ".join(args))
	return fallback if m == null else int(m.get_string(1))


func _vec_arg(args: PackedStringArray, key: String) -> PackedFloat64Array:
	var re := RegEx.new()
	re.compile("(?i)\\b%s=(?:(-?\\d+\\.?\\d*),\\s*(-?\\d+\\.?\\d*),\\s*(-?\\d+\\.?\\d*))" % key)
	var m: RegExMatch = re.search(" ".join(args))
	if m == null:
		return PackedFloat64Array()
	return PackedFloat64Array([float(m.get_string(1)), float(m.get_string(2)), float(m.get_string(3))])


func _collect_meshes(from: Node, out: Array[Node]) -> void:
	for c: Node in from.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			out.append(c)
		_collect_meshes(c, out)
