static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}

static func _q(c: Color) -> Color:
	return Color(
		roundf(c.r * 16.0) / 16.0,
		roundf(c.g * 16.0) / 16.0,
		roundf(c.b * 16.0) / 16.0)

static func box(size: Vector3) -> BoxMesh:
	var key := "box:" + str(size)
	if _meshes.has(key):
		return _meshes[key]
	var m := BoxMesh.new()
	m.size = size
	_meshes[key] = m
	return m

static func sphere(radius: float, height: float, hemisphere := false) -> SphereMesh:
	var key := "sph:%f:%f:%s" % [radius, height, str(hemisphere)]
	if _meshes.has(key):
		return _meshes[key]
	var m := SphereMesh.new()
	m.radius = radius
	m.height = height
	m.is_hemisphere = hemisphere
	_meshes[key] = m
	return m

static func cylinder(top_r: float, bottom_r: float, height: float) -> CylinderMesh:
	var key := "cyl:%f:%f:%f" % [top_r, bottom_r, height]
	if _meshes.has(key):
		return _meshes[key]
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bottom_r
	m.height = height
	_meshes[key] = m
	return m

static func capsule(radius: float, height: float) -> CapsuleMesh:
	var key := "cap:%f:%f" % [radius, height]
	if _meshes.has(key):
		return _meshes[key]
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	_meshes[key] = m
	return m

static func torus(inner_r: float, outer_r: float) -> TorusMesh:
	var key := "tor:%f:%f" % [inner_r, outer_r]
	if _meshes.has(key):
		return _meshes[key]
	var m := TorusMesh.new()
	m.inner_radius = inner_r
	m.outer_radius = outer_r
	_meshes[key] = m
	return m

static func mat(color: Color, rough := 0.5, metallic := 0.0, alpha := 1.0, emissive := Color.WHITE, glow := 0.0) -> StandardMaterial3D:
	var qc := _q(color)
	var qe := _q(emissive)
	var key := "mat:%s:%d:%d:%d:%s:%d" % [qc, int(roundf(rough * 100.0)), int(roundf(metallic * 100.0)), int(roundf(alpha * 100.0)), qe, int(roundf(glow * 100.0))]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(qc.r, qc.g, qc.b, alpha)
	m.roughness = rough
	m.metallic = metallic
	m.vertex_color_use_as_albedo = true
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = qe
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m

static func multimesh(mesh: Mesh, transforms: Array, colors: Array = [], aabb := AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors.size() > 0
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if colors.size() > 0:
			mm.set_instance_color(i, colors[i])
	mm.custom_aabb = aabb
	return mm
