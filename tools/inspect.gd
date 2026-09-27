extends SceneTree

# Introspect a scene tree: prints node paths, mesh AABBs (local + world), and material
# info. Used to author geometry offsets (e.g. turtle pupils).
# Usage: godot --path . --script res://tools/inspect.gd -- <scene> [name_filter]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = argv[0]
	var filter: String = String(argv[1]) if argv.size() > 1 else ""
	var packed: PackedScene = load(scene_path)
	if packed == null:
		printerr("INSPECT FAIL ", scene_path)
		quit(1)
		return
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	await process_frame
	_dump(world, world, filter)
	quit(0)


func _dump(node: Node, root: Node, filter: String) -> void:
	if filter.is_empty() or String(node.name).to_lower().contains(filter.to_lower()):
		_print_node(node)
		if node is Node3D and String(node.name).to_lower().contains(filter.to_lower()):
			_print_frame(node as Node3D)
	for child in node.get_children():
		_dump(child, root, filter)


## Prints a node's transform in its parent's frame plus the AABB of each child mesh
## expressed in THIS node's local space — that is the frame new child geometry must use.
func _print_frame(n: Node3D) -> void:
	print("   FRAME %s" % n.get_path())
	print("      xform_in_parent.origin=%s basis.x=%s y=%s z=%s" % [
		n.transform.origin, n.transform.basis.x, n.transform.basis.y, n.transform.basis.z])
	print("      scale=%s" % n.transform.basis.get_scale())
	for child in n.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child
			var mesh: Mesh = mi.mesh
			if mesh == null:
				continue
			var aabb: AABB = mesh.get_aabb()
			# mesh AABB is in mesh space; bring it into this node's space
			var local: AABB = n.global_transform.affine_inverse() * (mi.global_transform * aabb)
			print("      child %s aabb_in_frame pos=%s size=%s end=%s" % [
				mi.name, local.position, local.size, local.position + local.size])
		elif child is Node3D:
			_print_frame(child as Node3D)


func _print_node(node: Node) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		var mesh: Mesh = mi.mesh
		var vcount: int = 0
		if mesh != null and mesh.get_surface_count() > 0:
			vcount = mesh.surface_get_array_len(0) / 3
		print("MESH %s" % node.get_path())
		if mesh != null:
			var aabb: AABB = mesh.get_aabb()
			print("   local_aabb  pos=%s size=%s" % [aabb.position, aabb.size])
			print("   world_aabb  pos=%s size=%s" % [(node.global_transform * aabb).position, aabb.size])
		print("   origin=%s scale=%s skin=%s" % [node.global_position, node.global_transform.basis.get_scale(), mi.skin != null])
		print("   surfaces=%d verts=%d" % [mesh.get_surface_count() if mesh != null else 0, vcount])
	elif node is Node3D:
		var n3: Node3D = node
		print("NODE %s (%s) pos=%s" % [node.get_path(), node.get_class(), n3.global_position])
	else:
		print("NODE %s (%s)" % [node.get_path(), node.get_class()])
