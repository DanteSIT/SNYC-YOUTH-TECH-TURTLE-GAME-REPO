extends Area3D

## Pollution / debris hazard. The visual body is a downloaded CC0 model
## (set `model_scene` per instance) instead of being built in code, so the
## hazard is fully editable in the scene that defines it. The hitbox is fitted
## to the model's bounds at load. Behaviour: optional bob and left/right patrol.

@export var damage := 25
@export var patrol_end := Vector3.ZERO
@export_range(0.0, 10.0) var patrol_speed := 1.5
@export var model_scene: PackedScene
@export var model_scale := 1.0
@export_range(0.0, 2.0) var bob_amplitude := 0.0
@export_range(0.0, 6.0) var bob_speed := 1.4
@export_range(0.0, 6.28) var start_spin := 0.0

var _patrol_start: Vector3
var _patrol_dir := 1.0
var _t := 0.0
var _base_y := 0.0
var _body: Node3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_patrol_start = global_position
	_base_y = global_position.y
	_t = start_spin
	_spawn_model()
	_fit_collision()


func _spawn_model() -> void:
	if model_scene == null:
		return
	var inst: Node3D = model_scene.instantiate()
	inst.name = "Body"
	inst.scale = Vector3.ONE * model_scale
	add_child(inst)
	_body = inst


## Build a box hitbox that matches the spawned model's real bounds.
func _fit_collision() -> void:
	var col: CollisionShape3D = $CollisionShape3D
	var box := BoxShape3D.new()
	if _body != null:
		var aabb := _mesh_aabb(_body)
		box.size = aabb.size.max(Vector3(0.5, 0.5, 0.5))
		col.position = aabb.get_center()
	else:
		box.size = Vector3(1.2, 1.2, 1.2)
	col.shape = box


func _mesh_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var self_inv := global_transform.affine_inverse()
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		if mi.mesh == null:
			continue
		var a: AABB = mi.get_aabb()
		var xf: Transform3D = self_inv * mi.global_transform
		a = xf * a
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	if first:
		out = AABB(Vector3.ZERO, Vector3.ONE)
	return out


func _physics_process(delta: float) -> void:
	_t += delta
	if bob_amplitude > 0.0:
		global_position.y = _base_y + sin(_t * bob_speed) * bob_amplitude
	if _body != null:
		_body.rotation.y = _t * 0.25
	if patrol_end == Vector3.ZERO:
		return
	var target := _patrol_start + patrol_end if _patrol_dir > 0.0 else _patrol_start
	var from := global_position
	var next := from.move_toward(target, patrol_speed * delta)
	next.y = global_position.y
	global_position = next
	if from.distance_to(target) < 0.02:
		_patrol_dir *= -1.0


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
