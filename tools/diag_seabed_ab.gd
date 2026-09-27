extends SceneTree
## In-process A/B of the seabed, through the real player camera, with the real
## sand material. This is the technique that actually settles visibility questions
## in this project: two renders inside ONE process, so the animated fish, the
## particles and the water cannot differ between them the way they do across
## processes. Every cross-process comparison so far has been unreliable, and two
## wrong conclusions came out of that.
##
## Why the earlier attempts were misleading:
##   * counting magenta pixels failed, because the underwater grade tints magenta
##     toward blue and it stopped matching the detector's g < 0.35 test;
##   * counting how much hiding the bed changed the frame across processes also
##     failed, because the animated scene changes on its own between runs.
##
## Here both frames come from the same process a few frames apart with the turtle
## pinned, so anything that differs is attributable to the bed.
##
## Usage:
##   godot --path . --script res://tools/diag_seabed_ab.gd -- res://scenes/levels/level_1.tscn

const W := 640
const H := 360


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = argv[0] if argv.size() > 0 else "res://scenes/levels/level_1.tscn"
	var world: Node = (load(scene_path) as PackedScene).instantiate()
	get_root().add_child(world)
	current_scene = world
	get_root().size = Vector2i(W, H)

	var turtle: Node3D = world.get_node_or_null("Turtle/CharacterBody3D")
	var cam: Camera3D = _player_camera(world)
	var bed: MeshInstance3D = world.get_node_or_null("Terrain/SeabedBody/Seabed")
	if cam == null or bed == null:
		printerr("missing camera or seabed")
		quit(1)
		return

	for _i in 10:
		await process_frame
	_pin(turtle)
	print("camera ", cam.global_position, "  fov=", cam.fov)

	bed.visible = true
	var on: Image = await _shoot(cam, turtle)
	bed.visible = false
	var off: Image = await _shoot(cam, turtle)
	bed.visible = true

	on.save_png("/tmp/opencode/ab_on.png")
	off.save_png("/tmp/opencode/ab_off.png")

	print("")
	print("in-process A/B through the player camera, %dx%d" % [W, H])
	print("  band (top->bottom)   pixels changed by the seabed   mean R,G,B with / without")
	for band: Array in [["top    ", 0.0, 0.25], ["upper  ", 0.25, 0.5], ["lower  ", 0.5, 0.75], ["bottom ", 0.75, 1.0]]:
		var y0: int = int(H * float(band[1]))
		var y1: int = int(H * float(band[2]))
		var tot: int = 0
		var ch: int = 0
		var r1: float = 0.0
		var g1: float = 0.0
		var b1: float = 0.0
		var r0: float = 0.0
		var g0: float = 0.0
		var b0: float = 0.0
		for y: int in range(y0, y1):
			for x: int in range(W):
				var a: Color = on.get_pixel(x, y)
				var b: Color = off.get_pixel(x, y)
				tot += 1
				r1 += a.r
				g1 += a.g
				b1 += a.b
				r0 += b.r
				g0 += b.g
				b0 += b.b
				if absf(a.r - b.r) > 0.02 or absf(a.g - b.g) > 0.02 or absf(a.b - b.b) > 0.02:
					ch += 1
		print("  %s          %5.1f%%                  %3d,%3d,%3d  /  %3d,%3d,%3d" % [
			band[0], 100.0 * ch / tot,
			int(r1 / tot * 255.0), int(g1 / tot * 255.0), int(b1 / tot * 255.0),
			int(r0 / tot * 255.0), int(g0 / tot * 255.0), int(b0 / tot * 255.0)])
	quit()


func _pin(t: Node3D) -> void:
	if t == null:
		return
	t.global_position = Vector3(0.0, 0.8, 40.6)
	if "velocity" in t:
		t.set("velocity", Vector3.ZERO)


func _shoot(cam: Camera3D, turtle: Node3D) -> Image:
	for _i in 8:
		_pin(turtle)
		await process_frame
	return cam.get_viewport().get_texture().get_image()


func _player_camera(world: Node) -> Camera3D:
	var found: Array[Node] = []
	_collect(world, found)
	for c: Node in found:
		if c is Camera3D and (c as Camera3D).current:
			return c
	return null


func _collect(from: Node, out: Array[Node]) -> void:
	for c: Node in from.get_children():
		out.append(c)
		_collect(c, out)
