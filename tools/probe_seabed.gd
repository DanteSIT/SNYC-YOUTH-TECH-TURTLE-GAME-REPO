extends SceneTree
## Validates the seabed in every level actually renders, not just collides.
##
## WHY THIS EXISTS
## ---------------
## The seabed used to be serialised as an ArrayMesh `_data` dictionary holding
## PackedVector3Arrays. Godot parses that with no error and no warning and
## produces a mesh whose surface_count is 0 -- a mesh that draws nothing. The
## scene still loaded, still reported no errors, and still collided perfectly,
## because collision lives in a separate CollisionShape3D. Both the load check
## and the floor probe passed, 16 levels out of 16, while the entire seabed was
## invisible on screen.
##
## So every one of those checks was blind to the only question that mattered.
## This one is not: it loads each level, pulls the seabed mesh out of the running
## scene, and requires a real surface with real triangles facing the right way.
##
## Usage:
##   godot --headless --path . --script res://tools/probe_seabed.gd

const LEVEL_DIR := "res://scenes/levels/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dir := DirAccess.open(LEVEL_DIR)
	if dir == null:
		printerr("SEABED: cannot open ", LEVEL_DIR)
		quit(1)
		return
	var files: Array[String] = []
	for f: String in dir.get_files():
		if f.ends_with(".tscn"):
			files.append(f)
	files.sort()
	var bad := 0
	for f: String in files:
		if not await _probe(LEVEL_DIR + f, f):
			bad += 1
	print("")
	if bad == 0:
		print("SEABED OK  %d/%d levels have a visible, correctly wound sand surface" % [
			files.size(), files.size()])
	else:
		printerr("SEABED FAIL  %d/%d levels have no renderable seabed" % [bad, files.size()])
	quit(1 if bad > 0 else 0)


func _probe(path: String, label: String) -> bool:
	var level: Node = (load(path) as PackedScene).instantiate()
	get_root().add_child(level)
	await process_frame
	var seabed: MeshInstance3D = level.find_child("Seabed", true, false)
	var problems: Array[String] = []
	if seabed == null:
		problems.append("no Seabed MeshInstance3D")
	elif seabed.mesh == null:
		problems.append("Seabed has no mesh")
	else:
		var mesh: Mesh = seabed.mesh
		# The check that would have caught this the moment it was introduced.
		if mesh.get_surface_count() != 1:
			problems.append("surface_count is %d, expected 1 (mesh draws nothing)" % mesh.get_surface_count())
		else:
			problems.append_array(_triangles(mesh))
		if seabed.material_override == null:
			problems.append("no material_override, so it renders unshaded-grey")
		if not seabed.visible:
			problems.append("Seabed is not visible")
	level.queue_free()
	await process_frame
	if problems.is_empty():
		print("  %-18s ok" % label)
		return true
	for p: String in problems:
		printerr("  %-18s FAIL  %s" % [label, p])
	return false


## Counts the triangles by orientation. The bed is a horizontal surface plus one
## vertical skirt, so a correct mesh has plenty of up-facing tris AND plenty of
## +X-facing ones.
##
## The sign convention below is not the OpenGL one and getting it wrong is
## invisible: Godot's front faces are CLOCKWISE, so a triangle is front-facing
## iff its right-hand-rule normal points AWAY from the viewer. An earlier version
## of this check required n.y > 0.5, i.e. the OpenGL assumption, and therefore
## passed a bed that could only be seen from underneath while reporting it as
## correctly wound. tools/probe_winding.gd measures the real convention.
##
## The top surface is watched from above, so it must wind to a right-hand normal
## of -Y. The skirt stands on the far (-X) edge and is watched from +X, where the
## camera is, so it must wind to -X.
func _triangles(mesh: Mesh) -> Array[String]:
	var out: Array[String] = []
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if verts.is_empty():
		out.append("surface has no vertices")
		return out
	if idx.is_empty():
		out.append("surface has no indices")
		return out
	var top_ok := 0
	var skirt_ok := 0
	var tris: int = idx.size() / 3
	for t: int in range(tris):
		var a: Vector3 = verts[idx[t * 3]]
		var b: Vector3 = verts[idx[t * 3 + 1]]
		var c: Vector3 = verts[idx[t * 3 + 2]]
		var n: Vector3 = (b - a).cross(c - a).normalized()
		if n.y < -0.5:
			top_ok += 1
		elif n.x < -0.9:
			skirt_ok += 1
	if tris > 0 and float(top_ok) / float(tris) < 0.5:
		out.append("only %d/%d triangles face up -- the sand is inside-out and cull_back will hide it from above" % [top_ok, tris])
	if skirt_ok < 10:
		out.append("only %d far-edge skirt triangles facing the camera, expected a continuous wall on the -X edge" % skirt_ok)
	return out
