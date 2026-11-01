extends Control

## Draws the three result stars. Kept as a custom control so the stars need no
## font glyphs and can be animated in one place.

const COUNT := 3
const FILLED := Color(1.0, 0.82, 0.34, 1.0)
const EMPTY := Color(0.12, 0.24, 0.30, 0.95)
const FILLED_EDGE := Color(1.0, 0.94, 0.68, 1.0)
const EMPTY_EDGE := Color(0.32, 0.50, 0.58, 0.65)

var stars := 0


func set_stars(value: int) -> void:
	stars = clampi(value, 0, COUNT)
	queue_redraw()
	# A short fade makes the earned stars feel like a reward rather than a
	# number that was already on the screen.
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.28)


func _draw() -> void:
	var radius := minf(size.x / (COUNT * 2.7), size.y * 0.44)
	for i in COUNT:
		var centre := Vector2(size.x * (i + 0.5) / COUNT, size.y * 0.5)
		var filled := i < stars
		if filled:
			draw_colored_polygon(_star(centre, radius * 1.14, radius * 0.52),
				Color(FILLED.r, FILLED.g, FILLED.b, 0.16))
		var points := _star(centre, radius, radius * 0.45)
		draw_colored_polygon(points, FILLED if filled else EMPTY)
		points.append(points[0])
		draw_polyline(points, FILLED_EDGE if filled else EMPTY_EDGE, 2.0, true)


func _star(centre: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var r := outer if i % 2 == 0 else inner
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * r)
	return points
