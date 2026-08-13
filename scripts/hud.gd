extends CanvasLayer

func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.jellyfish_changed.connect(_on_jellyfish_changed)
	_on_score_changed(GameManager.score)
	_on_health_changed(GameManager.health)
	_on_jellyfish_changed(GameManager.jellyfish)

func _on_score_changed(value: int) -> void:
	$ScoreLabel.text = "Score : %d" % value

func _on_health_changed(value: int) -> void:
	$HealthLabel.text = "Health : %d / %d" % [value, GameManager.MAX_HEALTH]
	$HealthBar.size.x = 250.0 * float(value) / float(GameManager.MAX_HEALTH)

func _on_jellyfish_changed(value: int) -> void:
	$JellyfishLabel.text = "Jellyfish : %d" % value
