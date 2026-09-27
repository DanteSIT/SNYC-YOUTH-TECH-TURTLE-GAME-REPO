extends SceneTree
## One-off: why does the seabed contribute nothing to the frame?
##
## The winding is now correct (probe_seabed.gd agrees, and probe_winding.gd
## confirms the convention), and probe_floor.gd says the collider is solid. Yet
## rendering with and without the bed gives pixel-identical mean colours, so it
## is not being drawn at all. This prints the facts that distinguish the
## remaining candidates: a degenerate or mis-transformed AABB, a render layer
## the camera does not cull, an occluding mesh stacked on top of it, or the bed
## simply being outside the frustum.
##
## Usage:
##   godot --headless --path . --script res://tools/diag_seabed_view.gd -- res://scenes/levels/level_1.tscn


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = argv[0] if argv.size() > 0 else "res://scenes/levels/level_1.tscn"
	var packed: PackedScene = load(scene_path)
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	for _i in 12:
		await process_frame

	var bed: Node = world.get_node_or_null("Terrain/SeabedBody/Seabed")
	print("\nscene: ", scene_path)
	print("--- seabed node ---")
	if bed == null:
		printerr("no Terrain/SeabedBody/Seabed")
		quit(1)
		return
	var mi: MeshInstance3D = bed
	print("  visible            : ", mi.visible)
	print("  layers             : ", mi.layers)
	print("  global_transform   : ", mi.global_transform)
	print("  extra_cull_margin  : ", mi.extra_cull_margin)
	var mesh: Mesh = mi.mesh
	if mesh == null:
		printerr("  mesh is NULL")
		quit(1)
		return
	print("  surface_count      : ", mesh.get_surface_count())
	print("  surface material   : ", mesh.surface_get_material(0))
	print("  material_override  : ", mi.material_override)
	print("  mesh AABB (local)  : ", mesh.get_aabb())
	var aabb: AABB = mesh.get_aabb()
	var gx: AABB = mi.global_transform * aabb
	print("  mesh AABB (global) : ", gx)
	print("  corners            :")
	for c: Vector3 in [gx.position, gx.position + gx.size]:
		print("      ", c)

	print("\n--- cameras in the scene ---")
	var cams: Array[Node] = []
	_collect_cameras(world, cams)
	for c: Node in cams:
		var cam: Camera3D = c
		print("  ", cam.get_path(), "  current=", cam.current)
		print("      pos=", cam.global_position, " fov=", cam.fov, " near=", cam.near, " far=", cam.far)
		print("      cull_mask=", cam.cull_mask, " keep_aspect=", cam.keep_aspect, " layers=", cam.cull_mask)
		# How much of the bed is even inside this camera's frustum?
		var hits: int = 0
		var total: int = 0
		for i: int in range(9):
			for j: int in range(5):
				for k: int in range(3):
					var p: Vector3 = gx.position + Vector3(
						gx.size.x * i / 8.0, gx.size.y * j / 4.0, gx.size.z * k / 2.0)
					total += 1
					if cam.is_position_in_frustum(p):
						hits += 1
		print("      bed sample points inside frustum: %d/%d" % [hits, total])

	print("\n--- every MeshInstance3D whose AABB overlaps the bed (possible occluder) ---")
	var mis: Array[Node] = []
	_collect_meshes(world, mis)
	var n_overlap: int = 0
	for m: Node in mis:
		var g: MeshInstance3D = m
		if g.mesh == null:
			continue
		var gb: AABB = g.global_transform * g.mesh.get_aabb()
		if gb.intersects(gx):
			n_overlap += 1
			var is_bed: bool = g == mi
			print("  %s%s  AABB=%s  visible=%s" % [
				"  " if is_bed else "", g.get_path(), gb, g.visible])
	print("  (%d of %d meshes overlap the bed; the bed itself is listed first if present)" % [n_overlap, mis.size()])
	quit()


func _collect_cameras(from: Node, out: Array[Node]) -> void:
	for c: Node in from.get_children():
		if c is Camera3D:
			out.append(c)
		_collect_cameras(c, out)


func _collect_meshes(from: Node, out: Array[Node]) -> void:
	for c: Node in from.get_children():
		if c is MeshInstance3D:
			out.append(c)
		_collect_meshes(c, out)
