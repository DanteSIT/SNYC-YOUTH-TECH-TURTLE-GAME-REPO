extends Area3D

@export var flow := -0.6

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and "current_flow" in body:
		body.current_flow = flow

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and "current_flow" in body:
		body.current_flow = 0.0
