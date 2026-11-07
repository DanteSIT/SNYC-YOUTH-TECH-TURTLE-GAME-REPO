extends Area3D

## Defaults come from scripts/core/tuning.gd. Each instance can still override
## them in the inspector.
@export var points := Tuning.Collectable.POINTS
@export var bob_amplitude := Tuning.Collectable.BOB_HEIGHT
@export var bob_speed := Tuning.Collectable.BOB_SPEED
@export var sway_amount := Tuning.Collectable.SWAY
@export var spin_speed := Tuning.Collectable.SPIN_SPEED
## Name of the model node under this Area3D. Change this if you swap the
## jellyfish model for one with a different node name.
@export var model_node := "jeLLyfiSH"

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
	var pulse := Tuning.Collectable.PULSE_BASE \
		+ sin(t * Tuning.Collectable.PULSE_SPEED) * Tuning.Collectable.PULSE_SWAY
	for mat in _mats:
		if mat != null:
			mat.emission_energy_multiplier = pulse


func _apply_jelly_materials() -> void:
	var jelly: Node = get_node_or_null(model_node)
	if jelly == null:
		return
	var meshes: Array[Node] = []
	if jelly is MeshInstance3D:
		meshes.append(jelly)
	meshes.append_array(jelly.find_children("*", "MeshInstance3D", true, false))
	var dome_mat := _make_mat(Tuning.Collectable.DOME_COLOR,
		Tuning.Collectable.DOME_EMISSION)
	var tentacle_mat := _make_mat(Tuning.Collectable.TENTACLE_COLOR,
		Tuning.Collectable.TENTACLE_EMISSION)
	for node in meshes:
		var mesh_instance: MeshInstance3D = node
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue
		var bbox := mesh.get_aabb()
		var is_dome := bbox.size.y > bbox.size.x and bbox.size.y > bbox.size.z
		# Each surface gets its own material copy: the outline shell's grow
		# amount is tuned per mesh scale, and the dome copies are the ones the
		# pulse in _process() animates.
		var shell := GlowOutline.shell(
			load(Tuning.Assets.COLLECT_OUTLINE) as Material, mesh_instance)
		for surface_index in range(mesh.get_surface_count()):
			var mat := (dome_mat if is_dome else tentacle_mat).duplicate() as StandardMaterial3D
			mat.next_pass = shell
			if is_dome:
				_mats.append(mat)
			mesh_instance.set_surface_override_material(surface_index, mat)


func _make_mat(color: Color, emission_power: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.roughness = 0.35
	mat.emission_enabled = true
	mat.emission = Tuning.Collectable.DOME_GLOW
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
	crunch.stream = load(Tuning.Assets.COLLECT_SOUND) as AudioStream
	crunch.bus = "SFX"
	root.add_child(crunch)
	crunch.finished.connect(crunch.queue_free)
	crunch.play()


func _spawn_sparkles() -> void:
	var burst := (load(Tuning.Assets.FEEDBACK_BURST) as PackedScene).instantiate()
	burst.kind = 1
	var root := get_tree().current_scene
	if root == null:
		return
	root.add_child(burst)
	burst.global_position = global_position
