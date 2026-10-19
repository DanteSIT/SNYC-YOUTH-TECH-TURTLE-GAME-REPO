extends SceneTree

# Prints the combined world-space AABB of every MeshInstance3D in each scene passed
# as a user arg. Used to author scales/offsets when wrapping imported models.
# Usage: godot --headless --path . --script res://tools/probe_aabb.gd -- <scene> [scene...]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for p in OS.get_cmdline_user_args():
		var packed: PackedScene = load(p)
		if packed == null:
			print("FAIL %s" % p)
			continue
		var inst: Node = packed.instantiate()
		get_root().add_child(inst)
		var aabb := AABB()
		var first := true
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			var a: AABB = mi.global_transform * mi.mesh.get_aabb()
			aabb = a if first else aabb.merge(a)
			first = false
		print("%s|pos=%s|size=%s" % [p.get_file(), aabb.position, aabb.size])
		inst.queue_free()
	quit()
