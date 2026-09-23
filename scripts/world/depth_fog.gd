extends Node

## Dives the corridor: lerps the level's WorldEnvironment from a sunlit surface
## profile at the StartPipe towards a deeper profile at the EndPipe as the player
## swims forward. Also drives the screen-space underwater overlay so the grade,
## tint and caustic strength deepen with the dive. Reusable on any level.

@export var start_fog := Color(0.74, 0.9, 0.92)
@export var end_fog := Color(0.6, 0.82, 0.88)
@export var start_bg := Color(0.24, 0.58, 0.6)
@export var end_bg := Color(0.1, 0.42, 0.46)
@export var start_ambient := Color(0.7, 0.9, 0.93)
@export var end_ambient := Color(0.62, 0.85, 0.9)
@export var start_fog_energy := 2.0
@export var end_fog_energy := 1.8
@export var start_fog_density := 0.0025
@export var end_fog_density := 0.004
@export var start_vol_density := 0.005
@export var end_vol_density := 0.008

## Underwater overlay dive: how much the screen grade deepens start -> end.
@export_range(0.0, 1.0) var start_overlay_depth := 0.15
@export_range(0.0, 1.0) var end_overlay_depth := 0.75

@onready var _env: Environment = _find_environment()
@onready var _start_z: float = _pipe_z("StartPipe", 1.0)
@onready var _end_z: float = _pipe_z("EndPipe", -1.0)

var _t := 0.0
var _t_target := 0.0
var _grade: ShaderMaterial


func _ready() -> void:
	_grade = _find_grade()


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var span := _start_z - _end_z
	_t_target = clampf(inverse_lerp(_start_z, _end_z, player.global_position.z), 0.0, 1.0) if span != 0.0 else 1.0
	_t = move_toward(_t, _t_target, delta * 0.6)

	if _env != null:
		_env.fog_light_color = start_fog.lerp(end_fog, _t)
		_env.fog_light_energy = lerpf(start_fog_energy, end_fog_energy, _t)
		_env.background_color = start_bg.lerp(end_bg, _t)
		_env.ambient_light_color = start_ambient.lerp(end_ambient, _t)
		_env.fog_density = lerpf(start_fog_density, end_fog_density, _t)
		_env.volumetric_fog_density = lerpf(start_vol_density, end_vol_density, _t)

	if _grade != null:
		_grade.set_shader_parameter("depth", lerpf(start_overlay_depth, end_overlay_depth, _t))


func _find_environment() -> Environment:
	var world: WorldEnvironment = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null:
		return world.environment
	return null


func _find_grade() -> ShaderMaterial:
	var overlay: Node = get_parent().get_node_or_null("UnderwaterOverlay")
	if overlay == null:
		return null
	var rect: ColorRect = overlay.get_node_or_null("Grade") as ColorRect
	if rect == null:
		return null
	return rect.material as ShaderMaterial


func _pipe_z(pipe_name: String, fallback: float) -> float:
	var pipe: Node3D = get_parent().get_node_or_null(pipe_name) as Node3D
	if pipe == null:
		var goal: Node3D = get_parent().get_node_or_null("Goal") as Node3D
		return goal.global_position.z if goal != null else fallback
	return pipe.global_position.z