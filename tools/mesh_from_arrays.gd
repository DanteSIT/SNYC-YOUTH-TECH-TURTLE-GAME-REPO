extends SceneTree
## Builds ArrayMesh resources from a JSON array dump and saves them, so the
## on-disk layout is written by the engine's own resource writer.
##
## WHY THIS EXISTS
## ---------------
## ArrayMesh serialises as a `_surfaces` array of dictionaries, each holding
## interleaved PackedByteArray attribute buffers plus a `format` bitmask, a
## `primitive` enum, an `aabb` and a `uv_scale`. That layout is not documented.
##
## A plausible-looking alternative -- `_data` holding PackedVector3Array /
## PackedInt32Array -- parses with no error or warning whatsoever and produces a
## mesh whose surface_count is 0. Such a mesh renders absolutely nothing while
## the scene still loads, still casts no error, and still collides perfectly,
## because collision lives in a separate CollisionShape3D. That is exactly how an
## entire seabed can vanish while every automated check passes.
##
## Hand-encoding the byte buffers and the format bitmask is guesswork. Calling
## add_surface_from_arrays() and letting ResourceSaver do the writing is not.

const OUT_DIR := "res://.tmp_seabed"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 1:
		push_error("usage: mesh_from_arrays.gd -- <dump.json>")
		quit(1)
		return
	var fh := FileAccess.open(args[0], FileAccess.READ)
	if fh == null:
		push_error("cannot read %s" % args[0])
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(fh.get_as_text())
	fh.close()
	if not (parsed is Dictionary):
		push_error("dump is not a JSON object")
		quit(1)
		return
	var levels: Dictionary = parsed["levels"]
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var stems: Array = levels.keys()
	stems.sort()
	for stem: String in stems:
		if not _build_one(stem, levels[stem]):
			quit(1)
			return
	quit()


func _build_one(stem: String, job: Dictionary) -> bool:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays(job))
	# The failure mode being guarded against is a mesh that is quietly empty, so
	# refuse to emit one rather than shipping an invisible floor again.
	if mesh.get_surface_count() != 1:
		push_error("%s: surface_count is %d, expected 1" % [stem, mesh.get_surface_count()])
		return false
	if mesh.surface_get_array_len(0) <= 0:
		push_error("%s: surface has no vertices" % stem)
		return false
	var path := "%s/%s.tres" % [OUT_DIR, stem]
	if ResourceSaver.save(mesh, path) != OK:
		push_error("%s: ResourceSaver.save failed" % stem)
		return false
	print("MESHOK %s verts=%d idx=%d aabb=%s" % [
		stem, mesh.surface_get_array_len(0), (job["index"] as Array).size(),
		str(mesh.get_aabb())])
	return true


func _arrays(job: Dictionary) -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _to_vec3(job["vertex"])
	arrays[Mesh.ARRAY_NORMAL] = _to_vec3(job["normal"])
	arrays[Mesh.ARRAY_TEX_UV] = _to_vec2(job["uv"])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(job["index"])
	return arrays


func _to_vec3(src: Variant) -> PackedVector3Array:
	var flat: Array = src
	var count: int = flat.size() / 3
	var out := PackedVector3Array()
	out.resize(count)
	for i in count:
		var o: int = i * 3
		out[i] = Vector3(float(flat[o]), float(flat[o + 1]), float(flat[o + 2]))
	return out


func _to_vec2(src: Variant) -> PackedVector2Array:
	var flat: Array = src
	var count: int = flat.size() / 2
	var out := PackedVector2Array()
	out.resize(count)
	for i in count:
		var o: int = i * 2
		out[i] = Vector2(float(flat[o]), float(flat[o + 1]))
	return out
