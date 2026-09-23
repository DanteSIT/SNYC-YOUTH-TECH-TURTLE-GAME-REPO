extends SceneTree

var _rng := RandomNumberGenerator.new()
var _mats: Dictionary = {}

func _initialize() -> void:
	_rng.seed = 747
	_bake("res://scenes/objects/obstacle.tscn", "Obstacle", _bake_obstacle)
	_bake("res://scenes/objects/platform.tscn", "Platform", _bake_platform)
	print("SCENERY_DONE")
	quit()

func _mat(color: Color, rough := 0.9, emit := 0.0) -> StandardMaterial3D:
	var key := "%s_%d_%d" % [color, int(rough * 100.0), int(emit * 100.0)]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color.lightened(0.35)
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m

func _mi(mesh: Mesh, mat: StandardMaterial3D, pos := Vector3.ZERO, rot := Vector3.ZERO, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = sc
	return mi

func _set_owners(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_set_owners(child, root)

func _bake(path: String, root_name: String, build: Callable) -> void:
	var root := Node3D.new()
	root.name = root_name
	build.call(root)
	_set_owners(root, root)
	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, path)
	print("BAKE %s err=%d" % [path, err])

func _rock_mat(lighten := 0.0) -> StandardMaterial3D:
	return _mat(Color(0.30 + lighten, 0.28 + lighten, 0.25 + lighten), 0.95, 0.22)

func _moss_mat() -> StandardMaterial3D:
	return _mat(Color(0.20, 0.46, 0.23), 0.9, 0.14)

func _boulder(root: Node3D, sph: SphereMesh, mat: StandardMaterial3D, pos: Vector3, size: Vector3) -> void:
	root.add_child(_mi(sph, mat, pos,
		Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.4, 0.4)),
		size))

func _blade(root: Node3D, box: BoxMesh, base: Vector3, h: float, w: float, mat: StandardMaterial3D, segs := 4, bend := 0.22) -> void:
	var phase := _rng.randf_range(0.0, TAU)
	var seg_h := h / float(segs)
	var y := 0.0
	var frame := Transform3D.IDENTITY
	var prev_x := 0.0
	var prev_z := 0.0
	for s in range(segs):
		var t := float(s + 1) / float(segs)
		var bx := sin(phase + t * 1.8) * bend * t
		var bz := cos(phase * 0.8 + t * 1.3) * bend * t * 0.6
		var dx := bx - prev_x
		var dz := bz - prev_z
		prev_x = bx
		prev_z = bz
		frame = frame.translated(Vector3(0, seg_h, 0))
		var part := frame.translated(Vector3(dx, -seg_h * 0.5, dz))
		var seg_w := lerpf(w, w * 0.3, t)
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = mat
		mi.position = base + part.origin
		mi.basis = part.basis
		mi.scale = Vector3(seg_w, seg_h, 0.03)
		root.add_child(mi)

func _add_box_collision(root: Node3D, size := Vector3.ONE) -> void:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	root.add_child(body)

func _bake_obstacle(root: Node3D) -> void:
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	var rock := _rock_mat(0.05)
	var rock2 := _rock_mat(0.0)
	var moss := _moss_mat()
	_boulder(root, sph, rock, Vector3(0, -0.38, 0), Vector3(0.44, 0.4, 0.44))
	_boulder(root, sph, rock2, Vector3(0.06, 0.0, 0.08), Vector3(0.35, 0.32, 0.35))
	_boulder(root, sph, rock, Vector3(-0.09, 0.3, -0.05), Vector3(0.26, 0.24, 0.26))
	_boulder(root, sph, rock2, Vector3(0.05, 0.52, 0.04), Vector3(0.18, 0.17, 0.18))
	_boulder(root, sph, rock, Vector3(-0.02, 0.62, 0.02), Vector3(0.12, 0.12, 0.12))
	root.add_child(_mi(sph, moss, Vector3(0.04, 0.5, 0.1), Vector3.ZERO, Vector3(0.16, 0.07, 0.16)))
	root.add_child(_mi(sph, moss, Vector3(-0.08, 0.34, -0.06), Vector3.ZERO, Vector3(0.13, 0.06, 0.13)))
	_add_box_collision(root)

func _bake_platform(root: Node3D) -> void:
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	var box := BoxMesh.new()
	var rock := _rock_mat(0.05)
	var rock2 := _rock_mat(0.0)
	var moss := _moss_mat()
	_boulder(root, sph, rock, Vector3(0, -0.1, 0), Vector3(0.5, 0.18, 0.55))
	_boulder(root, sph, rock2, Vector3(0.32, -0.14, -0.12), Vector3(0.4, 0.15, 0.42))
	_boulder(root, sph, rock, Vector3(-0.3, -0.16, 0.14), Vector3(0.45, 0.17, 0.4))
	_boulder(root, sph, rock2, Vector3(0.05, 0.0, -0.28), Vector3(0.34, 0.12, 0.34))
	for i in range(5):
		var h := _rng.randf_range(0.16, 0.3)
		var base := Vector3(_rng.randf_range(-0.35, 0.35), 0.06, _rng.randf_range(-0.35, 0.35))
		_blade(root, box, base, h, 0.05, moss, 2, 0.1)
	_add_box_collision(root)

func _bake_rock_wall(root: Node3D) -> void:
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	var box := BoxMesh.new()
	var rock := _rock_mat(0.06)
	var rock2 := _rock_mat(0.0)
	var moss := _moss_mat()
	for i in range(7):
		var z := lerpf(-1.2, 1.2, float(i) / 6.0) + _rng.randf_range(-0.15, 0.15)
		var sz := _rng.randf_range(0.42, 0.62)
		var y := _rng.randf_range(0.15, 0.55) + sz * 0.4
		_boulder(root, sph, rock if i % 2 == 0 else rock2, Vector3(_rng.randf_range(-0.3, 0.3), y, z), Vector3(sz, sz * _rng.randf_range(0.8, 1.1), sz))
	for i in range(3):
		var z := _rng.randf_range(-0.9, 0.9)
		_boulder(root, sph, rock2, Vector3(_rng.randf_range(-0.25, 0.25), 1.05, z), Vector3(0.3, 0.26, 0.3))
	for i in range(3):
		root.add_child(_mi(sph, moss, Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0.9, 1.15), _rng.randf_range(-0.5, 0.5)), Vector3.ZERO, Vector3(0.22, 0.09, 0.22)))
	for i in range(3):
		var base := Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.15, 0.5), _rng.randf_range(-0.7, 0.7))
		_blade(root, box, base, _rng.randf_range(0.4, 0.8), 0.06, moss, 3, 0.14)
	for i in range(2):
		var base := Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0.6, 1.0), _rng.randf_range(-0.5, 0.5))
		_blade(root, box, base, _rng.randf_range(0.7, 1.2), 0.07, _mat(Color(0.16, 0.42, 0.2), 0.8, 0.15), 4, 0.3)
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 2.1, 2.4)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	body.position = Vector3(0, 1.05, 0)
	root.add_child(body)

func _mtn_mats() -> Array:
	var rock := _mat(Color(0.26, 0.31, 0.40), 1.0, 0.34)
	var rock2 := _mat(Color(0.21, 0.26, 0.35), 1.0, 0.28)
	return [rock, rock2]

func _bake_mountain_round(root: Node3D) -> void:
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	var m := _mtn_mats()
	_boulder(root, sph, m[1], Vector3(-2.4, 0.9, 1.6), Vector3(2.4, 1.8, 2.4))
	_boulder(root, sph, m[0], Vector3(2.1, 1.1, -1.8), Vector3(2.6, 2.0, 2.6))
	_boulder(root, sph, m[1], Vector3(0.4, 1.6, 0.2), Vector3(3.2, 2.4, 3.2))
	_boulder(root, sph, m[0], Vector3(-0.8, 2.6, 0.5), Vector3(2.4, 2.0, 2.4))
	_boulder(root, sph, m[1], Vector3(0.9, 3.6, -0.4), Vector3(1.6, 1.4, 1.6))
	_boulder(root, sph, m[0], Vector3(0.1, 4.8, 0.1), Vector3(1.1, 1.0, 1.1))

func _bake_mountain_blocky(root: Node3D) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var m := _mtn_mats()
	root.add_child(_mi(box, m[0], Vector3(0, 0.8, 0), Vector3.ZERO, Vector3(5.0, 1.6, 5.0)))
	root.add_child(_mi(box, m[1], Vector3(0, 2.3, 0.4), Vector3(0, 0, 0.12), Vector3(3.8, 1.4, 3.6)))
	root.add_child(_mi(box, m[0], Vector3(-1.6, 1.4, -2.0), Vector3(0, 0.7, 0), Vector3(2.2, 1.2, 1.8)))
	root.add_child(_mi(box, m[1], Vector3(0.4, 3.6, -0.1), Vector3.ZERO, Vector3(2.6, 1.2, 2.4)))
	root.add_child(_mi(box, m[0], Vector3(1.7, 2.0, 1.7), Vector3(0, -0.5, 0.15), Vector3(1.8, 1.4, 1.8)))
	root.add_child(_mi(box, m[1], Vector3(0.1, 4.9, 0.2), Vector3(0, 0.3, 0), Vector3(1.5, 1.1, 1.4)))
	root.add_child(_mi(box, m[0], Vector3(-0.3, 6.0, 0.1), Vector3(0.1, 0.2, -0.1), Vector3(0.8, 1.0, 0.8)))

func _bake_mountain_pointy(root: Node3D) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 1.0
	cone.height = 2.0
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	var m := _mtn_mats()
	_boulder(root, sph, m[1], Vector3(0.4, 0.9, 0.3), Vector3(3.0, 1.6, 3.0))
	root.add_child(_mi(cone, m[0], Vector3(0, 2.6, 0), Vector3.ZERO, Vector3(3.0, 3.6, 3.0)))
	root.add_child(_mi(cone, m[1], Vector3(2.0, 1.8, 1.6), Vector3(0.2, _rng.randf_range(-0.4, 0.4), 0.2), Vector3(1.6, 2.4, 1.6)))
	root.add_child(_mi(cone, m[0], Vector3(-2.2, 1.5, -1.4), Vector3(-0.15, _rng.randf_range(-0.4, 0.4), 0.15), Vector3(1.4, 2.2, 1.4)))
	root.add_child(_mi(cone, m[1], Vector3(0.2, 5.6, 0.0), Vector3.ZERO, Vector3(1.7, 2.8, 1.7)))
	root.add_child(_mi(cone, m[0], Vector3(0.15, 7.4, -0.1), Vector3(0.05, 0.3, 0.05), Vector3(1.0, 2.2, 1.0)))
