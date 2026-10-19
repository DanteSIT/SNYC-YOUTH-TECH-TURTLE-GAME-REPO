extends SceneTree

## Verifies the glow-outline wiring without needing an eye:
##   collectable  -> materials carry a pink next_pass shell
##   hazard*      -> every mesh material carries a red next_pass shell
## Also reports the world-space outline width each shell resolves to, since
## grow_amount is local and the models are scaled all over the place.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check("res://scenes/objects/collectable.tscn", "Collectable", Color(1, 0.38, 0.78))
	for h in ["hazard", "hazard_bottle", "hazard_can", "hazard_hook", "hazard_net"]:
		_check("res://scenes/objects/%s.tscn" % h, "Hazard", Color(1, 0.12, 0.08))
	quit()


func _check(scene_path: String, root_name: String, want: Color) -> void:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		print("FAIL  ", scene_path, " did not load")
		return
	var root: Node = packed.instantiate()
	get_root().add_child(root)

	var shells := 0
	var widths: Array[float] = []
	var color_ok := true
	for node in _meshes(root):
		var mi := node as MeshInstance3D
		for surface in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(surface)
			var next: Material = mat.next_pass if mat != null else null
			if next == null:
				print("  no next_pass on ", scene_path, "/", mi.name, " surface ", surface)
				continue
			shells += 1
			color_ok = color_ok and next.get("albedo_color").is_equal_approx(want)
			var s := mi.global_transform.basis.get_scale()
			widths.append(float(next.get("grow_amount")) * max(s.x, max(s.y, s.z)))

	print("%-38s shells=%d  color_ok=%s  world_width=%s" % [
		scene_path, shells, color_ok, _fmt(widths)])
	root.queue_free()


func _fmt(v: Array[float]) -> String:
	if v.is_empty():
		return "-"
	var lo: float = v.min()
	var hi: float = v.max()
	return "%.4f..%.4f" % [lo, hi]


func _meshes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		stack.append_array(n.get_children())
	return out
