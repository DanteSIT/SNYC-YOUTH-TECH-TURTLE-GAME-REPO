extends Area3D

## Ocean litter. Touching it costs health and shows a pulsing warning marker.
## Defaults live in scripts/core/tuning.gd; each instance can override them in
## the inspector.

@export var damage := Tuning.Hazard.DAMAGE
@export var patrol_end := Vector3.ZERO
@export_range(0.0, 10.0) var patrol_speed := Tuning.Hazard.PATROL_SPEED

var _patrol_start: Vector3
var _patrol_dir := 1.0
var _warning: Label3D
var _pulse := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_patrol_start = global_position
	GlowOutline.apply(self, load(Tuning.Assets.HAZARD_OUTLINE) as Material)
	_build_warning()

func _process(delta: float) -> void:
	if _warning == null:
		return
	_pulse += delta
	var beat := 0.5 + 0.5 * sin(_pulse * Tuning.Hazard.WARNING_PULSE_SPEED)
	_warning.modulate.a = lerpf(
		Tuning.Hazard.WARNING_ALPHA_MIN, Tuning.Hazard.WARNING_ALPHA_MAX, beat)
	_warning.scale = Vector3.ONE * (1.0 + Tuning.Hazard.WARNING_SCALE_SWAY * beat)

## A yellow "!" above the litter. The red glow alone is a colour-only cue, so
## the marker adds a shape and a pulse that survive colour blindness.
func _build_warning() -> void:
	_warning = Label3D.new()
	_warning.name = "WarningMarker"
	_warning.text = "!"
	_warning.font_size = Tuning.Hazard.WARNING_FONT_SIZE
	_warning.pixel_size = Tuning.Hazard.WARNING_PIXEL_SIZE
	_warning.outline_size = Tuning.Hazard.WARNING_OUTLINE_SIZE
	_warning.modulate = Tuning.Hazard.WARNING_COLOR
	_warning.outline_modulate = Color(0.02, 0.05, 0.08, 0.95)
	_warning.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_warning.position = Vector3(0.0, Tuning.Hazard.WARNING_HEIGHT, 0.0)
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
