extends Area3D

@export var points := 50
@export var bob_amplitude := 0.3
@export var bob_speed := 1.4
@export var sway_amount := 0.1
@export var spin_speed := 1.6

const DOME_COLOR := Color(0.78, 0.42, 0.9, 0.55)
const DOME_GLOW := Color(1.0, 0.75, 1.0)
const TENTACLE_COLOR := Color(0.9, 0.62, 0.96, 0.75)
const CRUNCH_SOUND := preload("res://assets/audio/jellyfish-plastic-crunch.mp3")
const SPARKLE_BURST := preload("res://scenes/effects/feedback_burst.tscn")

var _base_y := 0.0
var _mats: Array[StandardMaterial3D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_y = position.y
	_apply_jelly_materials()


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	rotation.y += delta * spin_speed
	position.y = _base_y + sin(t * bob_speed) * bob_amplitude
	rotation.z = sin(t * 0.8) * sway_amount * 0.5
	rotation.x = cos(t * 1.1) * sway_amount * 0.4
	var pulse := 1.2 + sin(t * 2.2) * 0.6
	for mat in _mats:
		if mat != null:
			mat.emission_energy_multiplier = pulse


func _apply_jelly_materials() -> void:
	var jelly: Node = get_node_or_null("jeLLyfiSH")
	if jelly == null:
		return
	var meshes: Array[Node] = []
	if jelly is MeshInstance3D:
		meshes.append(jelly)
	meshes.append_array(jelly.find_children("*", "MeshInstance3D", true, false))
	var dome_mat := _make_mat(DOME_COLOR, 1.6)
	var tentacle_mat := _make_mat(TENTACLE_COLOR, 0.8)
	_mats.append(dome_mat)
	for node in meshes:
		var mesh_instance: MeshInstance3D = node
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue
		for surface_index in range(mesh.get_surface_count()):
			var mat := tentacle_mat
			var bbox := mesh.get_aabb()
			if bbox.size.y > bbox.size.x and bbox.size.y > bbox.size.z:
				mat = dome_mat
			mesh_instance.set_surface_override_material(surface_index, mat)


func _make_mat(color: Color, emission_power: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = DOME_GLOW
	mat.emission_energy_multiplier = emission_power
	return mat


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameManager.add_jellyfish(1)
		GameManager.add_score(points)
		var animator: Node = body.get_node_or_null("PlayerAnimator")
		if animator != null and animator.has_method("play_eat"):
			animator.play_eat()
		_spawn_sparkles()
		_play_crunch()
		queue_free()


## The one-shot is parented to the current scene so it outlives this node, which
## queue_free()s itself immediately below. `current_scene` is null in headless
## --script runs (the screenshot and inspect tools), so the parent lookup has to
## be guarded or collecting a jellyfish from a tool hard-errors.
func _play_crunch() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var crunch := AudioStreamPlayer.new()
	crunch.stream = CRUNCH_SOUND
	crunch.bus = "SFX"
	root.add_child(crunch)
	crunch.finished.connect(crunch.queue_free)
	crunch.play()


func _spawn_sparkles() -> void:
	var burst := SPARKLE_BURST.instantiate()
	burst.kind = 1
	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(burst)
	burst.global_position = global_position
