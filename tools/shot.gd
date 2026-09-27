extends SceneTree

## Screenshot helper. Loads a scene, optionally repositions the player turtle, frames a
## camera and saves a PNG. Runs the scene for a few frames first so shaders, particles
## and the scenery baker settle before the capture.
##
## Usage:
##   godot --path . --script res://tools/shot.gd -- <scene> <out.png> [spec]
##
## <spec> is a comma-separated key=value list:
##   cam=x,y,z          free-camera position (ignored if the scene has a player camera)
##   look=x,y,z         free-camera aim point (default: 0,1.2,0)
##   turtle=x,y,z       move the "Turtle" node (or its CharacterBody3D) here
##   yaw=deg            rotate the turtle about Y so it swims toward the camera
##   w=,h=              output size (default 1280x720)
##   frames=n           frames to settle before capture (default 8)
##   hide=path,path     nodes to hide (comma separated sub-paths from the scene root)
##   hold=on            freeze the turtle's physics so it stays exactly at turtle=…
##                      (without this it sinks under gravity during the settle frames)
##   hud=off            hide the in-game HUD canvas
##   ortho=on           use an orthographic camera
##   ortho_size=n       orthographic half-height in world units (default 4)
##   freecam=on         honour cam=/look= even when the scene has a player
##                      camera, which is otherwise always preferred

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	if argv.size() < 2:
		printerr("SHOT: need <scene> <out.png>")
		quit(1)
		return
	var scene_path: String = argv[0]
	var out_path: String = argv[1]
	var spec: Dictionary = _parse_spec(argv[2] if argv.size() > 2 else "")

	var packed: PackedScene = load(scene_path)
	if packed == null:
		printerr("SHOT FAIL: cannot load ", scene_path)
		quit(1)
		return
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	# levels spawn one-shot SFX under current_scene; emulate a real scene load
	current_scene = world

	for hidden: String in String(spec.get("hide", "")).split(",", false):
		_hide(world, hidden)

	if spec.get("hud", "on") == "off":
		_hide(world, "Turtle/CanvasLayer")

	var turtle: Node3D = _find(world, "Turtle") as Node3D
	if spec.has("turtle"):
		var p: PackedFloat64Array = spec["turtle"]
		var target := Vector3(p[0], p[1], p[2])
		if turtle != null:
			turtle.global_position = target
		if spec.has("yaw"):
			turtle.rotate_y(deg_to_rad(float(spec["yaw"])))
	# The player body is pulled down by gravity every physics frame, so by the
	# time the settle frames are done it has long since left the requested spot --
	# and the camera follows it down, so every capture lands somewhere different
	# and nothing can be compared against a previous one. hold=on therefore has
	# to work even without turtle=, which it previously did not: the freeze sat
	# inside the `if spec.has("turtle")` branch above and was silently skipped.
	if spec.get("hold", "off") == "on":
		_freeze(turtle)
	var cam: Camera3D = _find_player_camera(turtle)
	var owned := false
	if cam == null or spec.get("freecam", "off") == "on":
		if cam != null:
			# A player camera would keep fighting the free camera for `current`.
			cam.queue_free()
		cam = Camera3D.new()
		world.add_child(cam)
		owned = true
		var cp: PackedFloat64Array = spec.get("cam", PackedFloat64Array([4.0, 2.0, 6.0]))
		cam.global_position = Vector3(cp[0], cp[1], cp[2])
		var lp: PackedFloat64Array = spec.get("look", PackedFloat64Array([0.0, 1.2, 0.0]))
		cam.look_at_from_position(cam.global_position, Vector3(lp[0], lp[1], lp[2]), Vector3.UP)
	if spec.get("ortho", "off") == "on":
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = float(spec.get("ortho_size", 4.0))
		cam.far = 2000.0
	if owned and spec.has("fov"):
		cam.fov = float(spec["fov"])
	cam.current = true

	var w: int = int(spec.get("w", 1280))
	var h: int = int(spec.get("h", 720))
	var vp: Viewport = get_root()
	vp.size = Vector2i(w, h)

	var frames: int = int(spec.get("frames", 8))
	for _i in range(frames):
		await process_frame

	var img: Image = vp.get_texture().get_image()
	var err: int = img.save_png(out_path)
	print("SHOT %s err=%d %dx%d" % [out_path, err, img.get_width(), img.get_height()])
	quit(0)


func _find_player_camera(turtle: Node3D) -> Camera3D:
	if turtle == null:
		return null
	var body: Node3D = turtle.get_node_or_null("CharacterBody3D") as Node3D
	if body != null:
		var cam: Camera3D = body.get_node_or_null("Camera3D") as Camera3D
		if cam != null:
			return cam
	return turtle.get_node_or_null("Camera3D") as Camera3D


func _find(from: Node, path: String) -> Node:
	if path.is_empty():
		return null
	return from.get_node_or_null(NodePath(path))


func _hide(from: Node, path: String) -> void:
	var node: Node = _find(from, path)
	# A CanvasLayer is neither CanvasItem nor Node3D, so the obvious isinstance
	# chain silently skipped the underwater grade. Duck-type on `visible` instead.
	for target: Node in [node, _first_child_with(node, "visible")]:
		if target != null and _has_property(target, "visible"):
			target.set("visible", false)


func _has_property(obj: Object, prop: String) -> bool:
	for p: Dictionary in obj.get_property_list():
		if p.get("name", "") == prop:
			return true
	return false


func _first_child_with(node: Node, prop: String) -> Node:
	if node == null:
		return null
	for child: Node in node.get_children():
		if _has_property(child, prop):
			return child
	return null


## Stops gravity from dragging the turtle out of the requested pose. The body sits at
## Turtle/CharacterBody3D, but fall back to the node itself so other rigs still work.
func _freeze(turtle: Node3D) -> void:
	var body: Node = turtle.get_node_or_null("CharacterBody3D")
	if body == null:
		body = turtle
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
		(body as CharacterBody3D).freeze = true


## Parses "cam=0,1,2,look=3" into {"cam": [0,1,2], "look": [3]}. Values run from one
## key= token to the next, so tuple values may contain commas.
func _parse_spec(text: String) -> Dictionary:
	var out: Dictionary = {}
	var re := RegEx.new()
	re.compile("([A-Za-z_][A-Za-z0-9_]*)=")
	var hits: Array[RegExMatch] = re.search_all(text)
	var tuple_keys: PackedStringArray = ["cam", "look", "turtle"]
	for i: int in range(hits.size()):
		var key: String = hits[i].get_string(1)
		var start: int = hits[i].get_end()
		var end: int = hits[i + 1].get_start() if i + 1 < hits.size() else text.length()
		var value: String = text.substr(start, end - start).strip_edges()
		if tuple_keys.has(key):
			var nums: Array[float] = []
			for piece: String in value.split(",", false):
				nums.append(float(piece))
			out[key] = PackedFloat64Array(nums)
		else:
			out[key] = value
	return out
