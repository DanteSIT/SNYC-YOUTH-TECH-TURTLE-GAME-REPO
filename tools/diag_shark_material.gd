extends SceneTree
## What material does the shark actually end up with?
##
## The user reports the shark has no textures. Two candidate causes, told apart
## here: the .glb's material never referenced a texture (the model ships untextured
## and something has to be authored), or it did reference one and the import threw
## it away (_subresources is empty, materials/extract=0, and the sibling
## zshark_Image.png is 250 bytes, which is about the size of a blank image rather
## than a texture).
##
## Usage:
##   godot --headless --path . --script res://tools/diag_shark_material.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/objects/shark_boss.tscn")
	var inst: Node = packed.instantiate()
	get_root().add_child(inst)
	for _i in 4:
		await process_frame

	var body: Node = inst.get_node_or_null("Body")
	var mis: Array[Node] = []
	if body != null:
		_collect(body, mis)
	print("shark_boss.tscn -> Body mesh nodes: ", mis.size())
	for m: Node in mis:
		var mi: MeshInstance3D = m
		var mesh: Mesh = mi.mesh
		print("")
		print("  node        : ", mi.get_path())
		print("  mesh class  : ", mesh.get_class(), "  surfaces: ", mesh.get_surface_count())
		for s: int in range(mesh.get_surface_count()):
			var mat: Material = mesh.surface_get_material(s)
			print("  surface %d   : %s  (%d verts, %d tris)" % [s, "null" if mat == null else mat.get_class(), mesh.surface_get_array_len(s), mesh.surface_get_array_index_count(s) if false else (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3])
			if mat == null:
				continue
			print("     resource_path : ", mat.resource_path)
			var sm: ShaderMaterial = mat as ShaderMaterial
			if sm != null:
				print("     shader        : ", sm.shader.resource_path if sm.shader != null else "null")
				for p: Dictionary in sm.shader.get_shader_uniform_list() if sm.shader != null else []:
					if "sampler" in str(p.get("hint", "")) or "sampler" in str(p.get("type", "")):
						print("     uniform       : ", p.get("name"), " = ", sm.get_shader_parameter(p.get("name")))
				continue
			var std: StandardMaterial3D = mat as StandardMaterial3D
			if std != null:
				var tex: Texture2D = std.albedo_texture
				print("     albedo_color  : ", std.albedo_color)
				print("     albedo_texture: ", "NONE" if tex == null else "%s %dx%d" % [
					tex.resource_path, tex.get_width(), tex.get_height()])
				print("     uv1_scale     : ", std.uv1_scale)
				print("     roughness     : ", std.roughness, "  metallic: ", std.metallic)
			var orm: ORMMaterial3D = mat as ORMMaterial3D
			if orm != null:
				print("     albedo_texture: ", "NONE" if orm.albedo_texture == null else orm.albedo_texture.resource_path)
	print("")
	print("override on the MeshInstance3D itself:")
	for m: Node in mis:
		print("  ", (m as MeshInstance3D).get_path(), " material_override = ",
			"null" if (m as MeshInstance3D).material_override == null else (m as MeshInstance3D).material_override.get_class())
	quit()


func _collect(from: Node, out: Array[Node]) -> void:
	for c: Node in from.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			out.append(c)
		_collect(c, out)
