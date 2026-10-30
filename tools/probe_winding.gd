extends SceneTree
## Measures which triangle winding Godot treats as front-facing. Godot uses the
## opposite convention from OpenGL, so this is checked instead of assumed.
##
## Run without --headless; headless mode has no rendering server.
## Usage: godot --path . --script res://tools/probe_winding.gd

const SIZE := Vector2i(400, 225)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	get_root().size = SIZE
	var cam: Camera3D = _make_camera()

	# 1. Warm-up. The first frames after the viewport is created are not
	#    trustworthy -- they can be blank or partially composited -- so they are
	#    rendered and discarded. This is the step whose absence made the earlier
	#    version of this script report a non-zero count for a culled face.
	for _i in 12:
		await process_frame
	print("warm-up done")

	# 2. Yardstick: how much of the frame does the quad occupy when it cannot be
	#    culled? Big quad, camera close, so this is most of the frame.
	var control: int = await _render(cam, [0, 1, 2, 1, 3, 2], BaseMaterial3D.CULL_DISABLED)
	var a: int = await _render(cam, [0, 1, 2, 1, 3, 2], BaseMaterial3D.CULL_BACK)
	var b: int = await _render(cam, [0, 2, 1, 1, 2, 3], BaseMaterial3D.CULL_BACK)

	var total: int = SIZE.x * SIZE.y
	print("")
	print("one quad seen FROM ABOVE, %d px frame" % total)
	print("  cull_disabled control (culling off)     : %6d px  %.1f%% of frame" % [
		control, 100.0 * control / total])
	print("  cull_back, right-hand normal +Y (UP)   : %6d px  %.1f%% of control" % [
		a, 100.0 * a / maxf(1.0, float(control))])
	print("  cull_back, right-hand normal -Y (DOWN) : %6d px  %.1f%% of control" % [
		b, 100.0 * b / maxf(1.0, float(control))])
	print("")

	# The control must be big enough to be a meaningful yardstick, or every
	# ratio below is noise.
	if control < total / 4:
		printerr("MEASUREMENT FAILED: the control quad only covered %.1f%% of the frame," % (100.0 * control / total))
		printerr("so the readings below cannot be compared. The test is broken, not the engine.")
		quit(1)
		return

	var a_front: bool = a > control / 2 and b < control / 20
	var b_front: bool = b > control / 2 and a < control / 20
	if a_front and not b_front:
		print("CONFIRMED: front faces are CLOCKWISE.")
		print("A surface is visible from above only if its right-hand normal points -Y.")
		quit(0)
	elif b_front and not a_front:
		print("UNEXPECTED: front faces follow the right-hand rule (+Y visible from above).")
		print("fix_seabed.py's winding and probe_seabed.gd both assume the opposite.")
		quit(1)
	else:
		printerr("MEASUREMENT FAILED: exactly one winding must clearly win.")
		printerr("Got +Y %.1f%% and -Y %.1f%% of the control." % [
			100.0 * a / maxf(1.0, float(control)), 100.0 * b / maxf(1.0, float(control))])
		quit(1)


func _make_camera() -> Camera3D:
	var cam := Camera3D.new()
	get_root().add_child(cam)
	# Angled, not straight down: a top-down look_at puts the view direction
	# parallel to UP and the orientation falls apart.
	cam.global_position = Vector3(0.0, 2.0, 7.0)
	cam.look_at_from_position(cam.global_position, Vector3.ZERO, Vector3.UP)
	cam.fov = 75.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.current = true
	return cam


func _render(cam: Camera3D, order: Array, cull: BaseMaterial3D.CullMode) -> int:
	# A 20x20 quad seen from 7 m at 75 deg vertical fov covers ~75% of the
	# height, so a front-facing one is unmistakable and a culled one is 0.
	var quad: PackedVector3Array = PackedVector3Array([
		Vector3(-10, 0, -10), Vector3(-10, 0, 10), Vector3(10, 0, -10), Vector3(10, 0, 10)])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = quad
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(order)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = cull

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	get_root().add_child(mi)

	for _i in 6:
		await process_frame

	var img: Image = cam.get_viewport().get_texture().get_image()
	var lit: int = 0
	if img != null:
		img.save_png("/tmp/opencode/winding_%s.png" % ("both" if cull == BaseMaterial3D.CULL_DISABLED else ("up" if order[1] == 1 else "down")))
		for y: int in img.get_height():
			for x: int in img.get_width():
				if img.get_pixel(x, y).r > 0.5:
					lit += 1
	else:
		printerr("no framebuffer -- run this WITHOUT --headless")
	mi.queue_free()
	await process_frame
	return lit
