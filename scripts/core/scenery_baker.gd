extends Node
## Runtime scenery baker: converts static decorative packed-scene instances
## into GPU-instanced MultiMesh draw calls on level load.
## Scene templates stay fully editable (.tscn); only rendering is batched.

## Only nodes tagged with this group are baked. The level generator tags
## decorative scatter (Kenney rocks/plants/logs/...) with it; gameplay nodes
## (hazards, enemies, collectables) are never tagged, so they stay dynamic.
const BAKE_GROUP := "bakeable"

var _last_scene_id := 0
var _mat_cache: Dictionary = {}

func _q(c: Color, q:= 16.0) -> Color:
	return Color(roundf(c.r * q) / q, roundf(c.g * q) / q, roundf(c.b * q) / q, c.a)

func _canonical(mat: Material) -> Material:
	if mat is not StandardMaterial3D:
		return mat
	var sm := mat as StandardMaterial3D
	if sm.albedo_texture != null or sm.normal_texture != null \
			or sm.metallic_texture != null or sm.roughness_texture != null \
			or sm.ao_texture != null or sm.emission_texture != null:
		return mat
	var key := "%s|%d|%d|%s|%s|%d|%d|%d" % [
		_q(sm.albedo_color),
		int(roundf(sm.roughness * 100.0)),
		int(roundf(sm.metallic * 100.0)),
		_q(sm.emission),
		int(roundf(sm.emission_energy_multiplier * 100.0)),
		sm.transparency,
		sm.shading_mode,
		sm.cull_mode]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var cm := StandardMaterial3D.new()
	cm.albedo_color = _q(sm.albedo_color)
	cm.roughness = roundf(sm.roughness * 100.0) / 100.0
	cm.metallic = sm.metallic
	cm.transparency = sm.transparency
	cm.shading_mode = sm.shading_mode
	cm.cull_mode = sm.cull_mode
	if sm.emission_enabled or sm.emission_energy_multiplier > 0.0:
		cm.emission_enabled = true
		cm.emission = _q(sm.emission)
		cm.emission_energy_multiplier = roundf(sm.emission_energy_multiplier * 100.0) / 100.0
	_mat_cache[key] = cm
	return cm

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var tree := get_tree()
	if tree == null:
		return
	var sc := tree.current_scene
	if sc == null or not sc is Node3D:
		_last_scene_id = 0
		return
	if sc.get_instance_id() == _last_scene_id:
		return
	var fname := sc.scene_file_path.get_file()
	if not (fname.begins_with("level_") or fname == "tutorial.tscn"):
		return
	await _bake(sc as Node3D)
	if is_instance_valid(sc) and sc is Node3D:
		_last_scene_id = sc.get_instance_id()

func _bake(level: Node3D) -> void:
	if not is_instance_valid(level) or not level.is_inside_tree():
		return
	var targets: Array[Node3D] = []
	for n in level.find_children("*", "", true, false):
		var cand := n as Node3D
		if cand == null:
			continue
		if cand.is_in_group(BAKE_GROUP) or _under_scenery(level, cand):
			targets.append(cand)

	if targets.is_empty():
		return

	var groups: Dictionary = {}
	for t in targets:
		if not is_instance_valid(t):
			continue
		for m in t.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi == null:
				continue
			var mesh: Mesh = mi.mesh
			if mesh == null:
				continue
			var mat: Material = null
			if mesh.get_surface_count() > 0:
				mat = mi.get_active_material(0)
			if mat != null:
				mat = _canonical(mat)
			var key: Variant = mesh.get_instance_id()
			if mat != null:
				key = "%s|%s" % [key, mat.get_instance_id()]
			if not groups.has(key):
				groups[key] = {"mesh": mesh, "mat": mat, "xforms": []}
			groups[key]["xforms"].append(mi.global_transform)

	var idx := 0
	for key in groups.keys():
		var g: Dictionary = groups[key]
		var xforms: Array = g["xforms"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = false
		var mmesh: Mesh = g["mesh"]
		var cur: Material = null
		if mmesh.get_surface_count() > 0:
			cur = mmesh.surface_get_material(0)
		if g["mat"] != null and cur != g["mat"]:
			var dup := mmesh.duplicate() as Mesh
			dup.surface_set_material(0, g["mat"])
			mm.mesh = dup
		else:
			mm.mesh = mmesh
		mm.instance_count = xforms.size()
		var aabb := AABB()
		var first := true
		for i in xforms.size():
			var xf: Transform3D = xforms[i]
			mm.set_instance_transform(i, xf)
			var p := AABB(xf.origin - Vector3.ONE, Vector3.ONE * 2.0)
			if first:
				aabb = p
				first = false
			else:
				aabb = aabb.merge(p)
		if first:
			aabb = AABB(Vector3.ZERO, Vector3.ONE)
		mm.custom_aabb = aabb
		var mmpi := MultiMeshInstance3D.new()
		mmpi.name = "BakedScenery%d" % idx
		mmpi.multimesh = mm
		level.add_child(mmpi)
		idx += 1

	for t in targets:
		if is_instance_valid(t):
			t.queue_free()

	if OS.is_debug_build():
		print("[SceneryBaker] %s: baked %d instances into %d MultiMesh groups" %
				[level.name, targets.size(), idx])


## True when `n` sits under a node named "Scenery" inside `level`.
func _under_scenery(level: Node, n: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != level:
		if p.name == "Scenery":
			return true
		p = p.get_parent()
	return false
