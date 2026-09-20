extends Node3D

const ResourceCache := preload("res://scripts/core/resource_cache.gd")

@export var fish_count := 10
@export var swim_forward := true
@export var bounds := Vector3(3.0, 1.8, 7.0)
@export var turn_speed := 2.5
@export var speed_range := Vector2(0.8, 1.6)
@export var scale_range := Vector2(0.35, 0.95)
@export var body_tint := Color(0.34, 0.62, 0.74)
@export var glow := false
@export var glow_tint := Color(0.45, 0.9, 1.0)

const FIN_S := Vector3(0.04, 0.34, 0.3)
const EYE_S := Vector3(0.09, 0.09, 0.05)
const BODY_S := Vector3(0.75, 0.55, 1.05)

static var TAIL_U := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0.55, -0.83), Vector3(0, 0.83, 0.55)), Vector3(0, 0.12, -0.09)).scaled(FIN_S)
static var TAIL_L := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0.55, 0.83), Vector3(0, -0.83, 0.55)), Vector3(0, -0.12, -0.09)).scaled(FIN_S)
static var DORSAL := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0.35, -0.94), Vector3(0, 0.94, 0.35)), Vector3(0, 0.26, -0.05)).scaled(FIN_S)
static var PECT_L := Transform3D(Basis(Vector3(0.25, -0.55, 0), Vector3(0.55, 0.25, 0), Vector3(0, 0, 1)), Vector3(-0.12, -0.05, 0.12)).scaled(FIN_S)
static var PECT_R := Transform3D(Basis(Vector3(0.25, 0.55, 0), Vector3(-0.55, 0.25, 0), Vector3(0, 0, 1)), Vector3(0.12, -0.05, 0.12)).scaled(FIN_S)
static var EYE_L := Transform3D.IDENTITY.translated(Vector3(-0.27, 0.08, 0.48)).scaled(EYE_S)
static var EYE_R := Transform3D.IDENTITY.translated(Vector3(0.27, 0.08, 0.48)).scaled(EYE_S)

var _body_mm: MultiMesh
var _fin_mm: MultiMesh
var _eye_mm: MultiMesh
var _fish: Array[Dictionary] = []

func _tint(base: Color) -> Color:
	var lightness := randf_range(0.85, 1.15)
	var c := Color(
		clampf(base.r * lightness, 0.0, 1.0),
		clampf(base.g * lightness, 0.0, 1.0),
		clampf(base.b * lightness, 0.0, 1.0))
	return c.lerp(c.lightened(0.12), randf() * 0.5)

func _ready() -> void:
	var body_transforms: Array = []
	var body_colors: Array = []
	var fin_transforms: Array = []
	var eye_transforms: Array = []
	for i in range(fish_count):
		var s := randf_range(scale_range.x, scale_range.y)
		body_transforms.append(Transform3D.IDENTITY)
		body_colors.append(_tint(body_tint))
		for j in range(5):
			fin_transforms.append(Transform3D.IDENTITY)
		eye_transforms.append(Transform3D.IDENTITY)
		eye_transforms.append(Transform3D.IDENTITY)
		_fish.append({
			"pos": Vector3(
				randf_range(-bounds.x, bounds.x),
				randf_range(-bounds.y, bounds.y),
				randf_range(-bounds.z, bounds.z)),
			"ry": PI if not swim_forward else 0.0,
			"s": s,
			"phase": randf() * TAU,
			"speed": randf_range(speed_range.x, speed_range.y),
			"wob": randf_range(0.4, 1.0),
			"wag": randf_range(1.8, 3.4),
			"dir": 1.0 if swim_forward else -1.0,
		})
	var aabb := AABB(Vector3(-bounds.x - 0.5, -bounds.y - 0.5, -bounds.z - 0.5),
		Vector3(2.0 * bounds.x + 1.0, 2.0 * bounds.y + 1.0, 2.0 * bounds.z + 1.0))
	var body_mat := ResourceCache.mat(Color.WHITE, 0.6, 0.0, 1.0, glow_tint, 0.8 if glow else 0.0)
	_body_mm = ResourceCache.multimesh(ResourceCache.sphere(0.5, 1.0), body_transforms, body_colors, aabb)
	_fin_mm = ResourceCache.multimesh(ResourceCache.box(Vector3.ONE), fin_transforms, [], aabb)
	_eye_mm = ResourceCache.multimesh(ResourceCache.box(Vector3.ONE), eye_transforms, [], aabb)
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = _body_mm
	bmi.material_override = body_mat
	add_child(bmi)
	var fmi := MultiMeshInstance3D.new()
	fmi.multimesh = _fin_mm
	fmi.material_override = ResourceCache.mat(Color(0.95, 0.5, 0.24), 0.5)
	add_child(fmi)
	var emi := MultiMeshInstance3D.new()
	emi.multimesh = _eye_mm
	emi.material_override = ResourceCache.mat(Color(0.03, 0.05, 0.07), 0.2)
	add_child(emi)

func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in range(_fish.size()):
		var e: Dictionary = _fish[i]
		var p: Vector3 = e.pos
		var dir: float = e.dir
		var sp: float = e.speed
		var wob: float = e.wob
		p.z += dir * sp * delta
		p.x += sin(e.phase + p.z * 1.1) * wob * sp * delta * dir
		p.y += sin(e.phase * 1.3 + p.z * 0.8) * wob * sp * delta * 0.6
		if dir > 0.0 and p.z > bounds.z:
			dir = -1.0
			p.z = bounds.z
		elif dir < 0.0 and p.z < -bounds.z:
			dir = 1.0
			p.z = -bounds.z
		p.x = clampf(p.x, -bounds.x, bounds.x)
		p.y = clampf(p.y, -bounds.y, bounds.y)
		e.pos = p
		e.dir = dir
		var target_yaw := PI if dir < 0.0 else 0.0
		var ry: float = e.ry
		var diff := angle_difference(ry, target_yaw)
		if absf(diff) > 0.02:
			ry += clampf(diff, -turn_speed * delta, turn_speed * delta)
		else:
			ry = target_yaw
		e.ry = ry
		var s: float = e.s
		var fish := Transform3D(Basis.IDENTITY, p).rotated(Vector3.UP, ry).scaled(Vector3(s, s, s))
		var wob_z := sin(t * e.wag * 0.5 + e.phase * 5.0) * 0.06
		_body_mm.set_instance_transform(i, fish * Transform3D(Basis.from_euler(Vector3(0, 0, wob_z)), Vector3.ZERO).scaled(BODY_S))
		var wag := sin(t * e.wag + e.phase * 4.0) * 0.35
		var tail := fish * Transform3D.IDENTITY.translated(Vector3(0, 0, -0.52)) * Transform3D(Basis.from_euler(Vector3(0, wag, 0)), Vector3.ZERO)
		var bi := i * 5
		_fin_mm.set_instance_transform(bi, tail * TAIL_U)
		_fin_mm.set_instance_transform(bi + 1, tail * TAIL_L)
		_fin_mm.set_instance_transform(bi + 2, fish * DORSAL)
		_fin_mm.set_instance_transform(bi + 3, fish * PECT_L)
		_fin_mm.set_instance_transform(bi + 4, fish * PECT_R)
		var ei := i * 2
		_eye_mm.set_instance_transform(ei, fish * EYE_L)
		_eye_mm.set_instance_transform(ei + 1, fish * EYE_R)
