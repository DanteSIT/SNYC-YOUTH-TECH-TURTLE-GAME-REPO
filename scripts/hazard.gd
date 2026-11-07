extends Area3D

@export var damage := 25
@export var patrol_end := Vector3.ZERO
@export_range(0.0, 10.0) var patrol_speed := 1.5

const OUTLINE := preload("res://materials/glow_outline_red.tres")
const WARNING_COLOR := Color(1.0, 0.86, 0.24, 1.0)

var _patrol_start: Vector3
var _patrol_dir := 1.0
var _warning: Label3D
var _pulse := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_patrol_start = global_position
	GlowOutline.apply(self, OUTLINE)
	_build_warning()

func _process(delta: float) -> void:
	if _warning == null:
		return
	_pulse += delta
	var beat := 0.5 + 0.5 * sin(_pulse * 4.0)
	_warning.modulate.a = 0.72 + 0.28 * beat
	_warning.scale = Vector3.ONE * (1.0 + 0.08 * beat)

## A yellow "!" above the litter. The red glow alone is a colour-only cue, so
## the marker adds a shape and a pulse that survive colour blindness.
func _build_warning() -> void:
	_warning = Label3D.new()
	_warning.name = "WarningMarker"
	_warning.text = "!"
	_warning.font_size = 56
	_warning.pixel_size = 0.008
	_warning.outline_size = 16
	_warning.modulate = WARNING_COLOR
	_warning.outline_modulate = Color(0.02, 0.05, 0.08, 0.95)
	_warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_warning.position = Vector3(0.0, 0.78, 0.0)
	add_child(_warning)

func _physics_process(delta: float) -> void:
	if patrol_end == Vector3.ZERO:
		return
	var target := _patrol_start + patrol_end if _patrol_dir > 0.0 else _patrol_start
	var from := global_position
	var next := from.move_toward(target, patrol_speed * delta)
	global_position = next
	if from.distance_to(target) < 0.02:
		_patrol_dir *= -1.0

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
