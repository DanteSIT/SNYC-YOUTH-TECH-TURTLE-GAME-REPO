extends Area3D

@export var points := 50
@export var bob_amplitude := 0.3
@export var bob_speed := 1.4
@export var sway_amount := 0.1
@export var spin_speed := 1.6

var _base_y := 0.0
var _shader: Shader


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_y = position.y
	_shader = load("res://shaders/jellyfish.gdshader")
	_apply_jelly_material()


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	rotation.y += delta * spin_speed
	position.y = _base_y + sin(t * bob_speed) * bob_amplitude
	rotation.z = sin(t * 0.8) * sway_amount * 0.5
	rotation.x = cos(t * 1.1) * sway_amount * 0.4


func _apply_jelly_material() -> void:
	var jelly: Node = get_node_or_null("jeLLyfiSH")
	if jelly == null:
		return
	var meshes: Array[Node] = []
	if jelly is MeshInstance3D:
		meshes.append(jelly)
	meshes.append_array(jelly.find_children("*", "MeshInstance3D", true, false))
	for node in meshes:
		var mesh_instance: MeshInstance3D = node
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var mat := ShaderMaterial.new()
			mat.shader = _shader
			mesh_instance.set_surface_override_material(surface, mat)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameManager.add_jellyfish(1)
		GameManager.add_score(points)
		queue_free()
