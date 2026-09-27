extends SceneTree
## Bisect: the seabed has valid data, a sane AABB, correct winding, a cull_back
## material and a visible node -- yet paints 0 pixels even when forced to
## unshaded magenta with culling disabled. That rules out winding, material and
## visibility, and leaves two possibilities:
##
##   (a) the mesh data itself does not rasterise (wrong primitive type, an
##       attribute format problem, an index buffer the renderer rejects);
##   (b) the mesh is fine and something opaque is drawn in front of it.
##
## So render the very same Mesh resource in a bare scene with a fresh camera
## pointed straight at it. Magenta present there means (b) -- the level is
## occluding it -- and magenta absent means (a) -- the mesh is at fault.
##
## Usage:
##   godot --path . --script res://tools/diag_seabed_bisect.gd -- res://scenes/levels/level_1.tscn

const W := 480
const H := 270


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	var scene_path: String = argv[0] if argv.size() > 0 else "res://scenes/levels/level_1.tscn"
	var packed: PackedScene = load(scene_path)
	var world: Node = packed.instantiate()
	get_root().add_child(world)
	get_root().size = Vector2i(W, H)
	for _i in 10:
		await process_frame

	var bed: MeshInstance3D = world.get_node_or_null("Terrain/SeabedBody/Seabed")
	if bed == null or bed.mesh == null:
		printerr("no seabed mesh")
		quit(1)
		return
	var mesh: Mesh = bed.mesh

	print("\n=== surface facts (read straight off the live resource) ===")
	print("  class                : ", mesh.get_class())
	print("  surface_count        : ", mesh.get_surface_count())
	print("  primitive_type       : %d  (0=POINTS 1=LINES 2=TRIANGLES ...)" % mesh.surface_get_primitive_type(0))
	print("  array_len (verts)    : ", mesh.surface_get_array_len(0))
	print("  surface format flags : ", mesh.surface_get_format(0))
	print("  aabb                 : ", mesh.get_aabb())
	var arrays: Array = mesh.surface_get_arrays(0)
	var slot_name: Array = ["VERTEX", "NORMAL", "TANGENT", "COLOR", "TEX_UV", "TEX_UV2", "BONES", "WEIGHTS"]
	for slot: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
		var v: Variant = arrays[slot]
		var label: String = slot_name[slot] if slot < slot_name.size() else str(slot)
		print("  ARRAY_%-13s: %s" % [label, _describe(v)])
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var oob: int = 0
	for i: int in idx:
		if i < 0 or i >= verts.size():
			oob += 1
	print("  indices out of range : ", oob)
	print("  first 6 vertices     : ", Array(verts.slice(0, 6)))
	print("  first 9 indices      : ", Array(idx.slice(0, 9)))

	# --- (a) the same Mesh resource, bare scene, fresh camera
	var holder := Node3D.new()
	get_root().add_child(holder)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _magma(BaseMaterial3D.CULL_DISABLED)
	holder.add_child(mi)
	# Straight down the +Y axis at the middle of the bed, close enough that the
	# bed fills the frame if it is drawn at all.
	var cam := Camera3D.new()
	get_root().add_child(cam)
	var mid: Vector3 = mesh.get_aabb().get_center()
	cam.global_position = Vector3(mid.x, mid.y + 12.0, mid.z)
	cam.look_at_from_position(cam.global_position, mid, Vector3.FORWARD)
	cam.fov = 75.0
	cam.current = true
	for _i in 14:
		await process_frame
	var img: Image = cam.get_viewport().get_texture().get_image()
	img.save_png("/tmp/opencode/bisect_bare.png")
	var bare: int = _count_magenta(img)
	print("\n=== bare scene, camera looking straight down at the bed ===")
	print("  magenta pixels       : %d of %d" % [bare, W * H])
	if bare == 0:
		print("  => the MESH does not rasterise. The level is not occluding it.")
		print("     Suspect the primitive type or the attribute format above.")
	else:
		print("  => the MESH is fine. Something in the level is drawn in front of it.")
		print("     Next step: hide the level's other children one at a time.")
	quit(0 if bare > 0 else 2)


func _describe(v: Variant) -> String:
	if v == null:
		return "null"
	if v is PackedInt32Array:
		return "PackedInt32Array size=%d" % (v as PackedInt32Array).size()
	if v is PackedVector3Array:
		return "PackedVector3Array size=%d" % (v as PackedVector3Array).size()
	if v is PackedVector2Array:
		return "PackedVector2Array size=%d" % (v as PackedVector2Array).size()
	return "%s size=%d" % [type_string(typeof(v)), (v as Array).size()]


func _magma(cull: BaseMaterial3D.CullMode) -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.0, 1.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = cull
	return m


func _count_magenta(img: Image) -> int:
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.55 and c.g < 0.35 and c.b > 0.55:
				n += 1
	return n
