extends Node3D
## One-shot feedback burst spawned at a world position.
## kind 0 = damage bubbles (white-blue), kind 1 = eat sparkles (amber-jelly).
## Editable scene (scenes/effects/feedback_burst.tscn); self-frees after its
## effect duration. process_mode is ALWAYS so the effect finishes even if the
## game is paused at the same moment it spawns.

enum Kind { BUBBLES, SPARKLE }

@export var kind: int = Kind.BUBBLES

var _ttl := 0.0

@onready var _bubbles: GPUParticles3D = $Bubbles
@onready var _sparkles: GPUParticles3D = $Sparkles


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var use := _bubbles if kind == Kind.BUBBLES else _sparkles
	_bubbles.visible = kind == Kind.BUBBLES
	_sparkles.visible = kind == Kind.SPARKLE
	use.one_shot = true
	use.explosiveness = 1.0
	use.emitting = true
	_ttl = use.lifetime + 0.4


func _process(delta: float) -> void:
	_ttl -= delta
	if _ttl <= 0.0:
		queue_free()