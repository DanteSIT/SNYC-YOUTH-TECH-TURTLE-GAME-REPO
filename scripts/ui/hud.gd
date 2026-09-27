extends CanvasLayer

## In-level HUD: health, score, jellyfish progress and the level clock.
##
## The clock is driven from here rather than from GameManager because the HUD is
## the only thing that exists for exactly the duration of a level. GameManager
## still owns the accumulated value, since reaching the goal swaps the whole
## level scene out for the results screen and the HUD goes with it.

var _best_shown := false


func _ready() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.jellyfish_changed.connect(_on_jellyfish_changed)
	_on_score_changed(GameManager.score)
	_on_health_changed(GameManager.health)
	_on_jellyfish_changed(GameManager.jellyfish)
	_refresh_time()
	# Counted a frame late on purpose: the HUD is ready before every collectable
	# in the level necessarily is, and "missed" is only meaningful against a
	# total that includes all of them.
	_count_collectables.call_deferred()


func _process(delta: float) -> void:
	GameManager.advance_level_time(delta)
	_refresh_time()


func _count_collectables() -> void:
	GameManager.set_level_jellyfish_total(get_tree().get_nodes_in_group("collectable").size())
	_on_jellyfish_changed(GameManager.jellyfish)


func _refresh_time() -> void:
	$TimerPanel/TimeLabel.text = GameManager.format_time(GameManager.level_time)
	if _best_shown:
		return
	var best: float = GameManager.best_time_for_level(GameManager.current_level)
	if best <= 0.0:
		return
	_best_shown = true
	$TimerPanel/BestLabel.text = "Best %s" % GameManager.format_time(best)


func _on_score_changed(value: int) -> void:
	$ScoreLabel.text = "Score : %d" % value


func _on_health_changed(value: int) -> void:
	$HealthLabel.text = "Health : %d / %d" % [value, GameManager.MAX_HEALTH]
	$HealthBar.size.x = 300.0 * float(value) / float(GameManager.MAX_HEALTH)


func _on_jellyfish_changed(value: int) -> void:
	# Collected and missed get their own labels rather than one long string: at
	# three digits the combined line is wide enough to run past the panel edge.
	$JellyfishLabel.text = "Jellyfish : %d / %d" % [value, GameManager.level_jellyfish_total]
	$MissedLabel.text = "Missed : %d" % GameManager.jellyfish_missed()
