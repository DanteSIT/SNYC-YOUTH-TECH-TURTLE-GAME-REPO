extends Node3D

## Tutorial coach for the practice level.
##
## Each step names one action and waits for it. A soft current holds the turtle
## at the step's gate until the action is done, so a fast player cannot skip an
## instruction. Informational steps advance when the player reaches the next
## gate. Progress lives in GameManager, so a lost life resumes at the same step.

const PANEL_BG := Color(0.035, 0.11, 0.18, 0.88)
const PANEL_BORDER := Color(0.32, 0.70, 0.86, 0.5)
const PANEL_DONE_BG := Color(0.02, 0.20, 0.16, 0.9)
const PANEL_DONE_BORDER := Color(0.34, 0.92, 0.6, 0.55)
const ACCENT := Color(0.24, 0.80, 0.95, 1.0)
const ACCENT_DONE := Color(0.40, 0.96, 0.58, 1.0)
const TEXT_COLOR := Color(0.90, 0.97, 1.0, 1.0)
const SUB_COLOR := Color(0.62, 0.82, 0.92, 1.0)
const DONE_COLOR := Color(0.60, 1.0, 0.78, 1.0)
const BLOCK_COLOR := Color(1.0, 0.78, 0.35, 1.0)
const ARROW_COLOR := Color(1.0, 0.85, 0.32, 0.97)
const ARROW_EDGE := Color(1.0, 0.98, 0.88, 0.55)

const PANEL_MARGIN := 26.0
const ARROW_MARGIN := 52.0
const ARROW_RADIUS := 20.0

## `mode` decides how a stage's target is resolved:
##   "point"         use the literal `target` position
##   "collectable"   the next uncollected jellyfish ahead of the turtle
##   "collectable_high"  ...restricted to the high ledge cluster
const STAGES: Array[Dictionary] = [
	{
		"z": 24.0,
		"msg": "Hold  RIGHT  or  D  to swim forward.",
		"done": "Good — you're swimming!",
		"cond": "swim",
		"mode": "point",
		"target": Vector3(0, 1.2, 20.0),
	},
	{
		"z": 21.0,
		"msg": "Press  UP / W  to rise and  DOWN / S  to dive.",
		"done": "You control your depth now.",
		"cond": "vertical",
		"mode": "point",
		"target": Vector3(0, 3.4, 19.0),
	},
	{
		"z": 18.0,
		"msg": "Careful! Plastic bags will hurt you. Swim around them.",
		"done": "Well dodged!",
		"cond": "none",
		"mode": "point",
		"target": Vector3(0, 3.27, 16.0),
	},
	{
		"z": 15.0,
		"msg": "Swim through the glowing jellyfish to collect them.",
		"done": "Nice catch! Keep collecting.",
		"cond": "collect",
		"mode": "collectable",
		"target": Vector3(0, 2.75, 14.5),
	},
	{
		"z": 11.0,
		"msg": "More jellyfish up on the ledge — swim up to reach them.",
		"done": "Up you go! Nice diving.",
		"cond": "collect",
		"mode": "collectable_high",
		"target": Vector3(0, 3.85, 8.9),
	},
	{
		"z": 5.0,
		"msg": "Hold  SHIFT  while swimming to BOOST!",
		"done": "So fast! That's your boost.",
		"cond": "boost",
		"mode": "point",
		"target": Vector3(0, 2.4, 2.0),
	},
	{
		"z": 2.0,
		"msg": "A current is carrying you forward. Stay steady and steer around the rocks.",
		"done": "Steady! You handled that.",
		"cond": "none",
		"mode": "point",
		"target": Vector3(0, 3.07, 0.0),
	},
	{
		"z": -6.0,
		"msg": "The reef gets deeper ahead — keep an eye out.",
		"done": "Almost there!",
		"cond": "none",
		"mode": "point",
		"target": Vector3(0, 1.4, -12.0),
	},
	{
		"z": -20.0,
		"msg": "Last stretch! Swim into the golden ring to finish.",
		"done": "You made it!",
		"cond": "none",
		"mode": "point",
		"target": Vector3(0, 1.5, -27.0),
	},
]

var _player: CharacterBody3D
var _stage := 0
var _ready_flags: Dictionary = {}
var _swim_time := 0.0
var _boost_time := 0.0
var _pressed_up := false
var _pressed_down := false
var _collected_at_stage_start := 0
var _blocked := false
var _pulse := 0.0

var _panel: PanelContainer
var _panel_style: StyleBoxFlat
var _accent: ColorRect
var _label: Label
var _sub_label: Label
var _step_label: Label
var _bar: ProgressBar
var _bar_bg: StyleBoxFlat
var _bar_fill: StyleBoxFlat
var _arrow: Polygon2D
var _ring: Polygon2D
var _panel_done := false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_stage = clampi(GameManager.tutorial_stage, 0, STAGES.size() - 1)
	_enter_stage()
	_build_hud()
	_respawn_at_stage()
	_update_panel()


## Start the current step with a clean slate. Called on load and whenever the
## player reaches the next gate.
func _enter_stage() -> void:
	_collected_at_stage_start = GameManager.jellyfish
	_swim_time = 0.0
	_boost_time = 0.0
	_pressed_up = false
	_pressed_down = false
	GameManager.tutorial_stage = _stage


## A life lost mid-lesson reloads the scene from the start pipe. Put the turtle
## back at the step it was on instead of making it swim the whole way again.
func _respawn_at_stage() -> void:
	if _stage <= 0 or _player == null:
		return
	_player.global_position = Vector3(0.0, 1.6, _stage_z(_stage) + 2.0)
	_player.velocity = Vector3.ZERO
	_player.snap_camera_to_body()


# --------------------------------------------------------------------- the HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = PANEL_BG
	_panel_style.set_corner_radius_all(16)
	_panel_style.set_border_width_all(2)
	_panel_style.border_color = PANEL_BORDER
	_panel_style.shadow_color = Color(0, 0, 0, 0.45)
	_panel_style.shadow_size = 10
	_panel_style.shadow_offset = Vector2(0, 4)
	_panel_style.content_margin_left = 18.0
	_panel_style.content_margin_right = 22.0
	_panel_style.content_margin_top = 12.0
	_panel_style.content_margin_bottom = 14.0

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -300.0
	_panel.offset_right = 300.0
	_panel.offset_top = -180.0
	_panel.offset_bottom = -24.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _panel_style)
	layer.add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	# A thin coloured spine down the left edge, so the card reads as a list item
	# and the "complete" state is visible at a glance.
	_accent = ColorRect.new()
	_accent.color = ACCENT
	_accent.custom_minimum_size = Vector2(5, 0)
	_accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_accent)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	# Step counter + progress bar share the top line.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)

	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 14)
	_step_label.add_theme_color_override("font_color", SUB_COLOR)
	head.add_child(_step_label)

	_bar_bg = StyleBoxFlat.new()
	_bar_bg.bg_color = Color(1, 1, 1, 0.12)
	_bar_bg.set_corner_radius_all(4)
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.bg_color = ACCENT
	_bar_fill.set_corner_radius_all(4)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = float(STAGES.size())
	_bar.value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 8)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.add_theme_stylebox_override("background", _bar_bg)
	_bar.add_theme_stylebox_override("fill", _bar_fill)
	head.add_child(_bar)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 21)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_label)

	_sub_label = Label.new()
	_sub_label.add_theme_font_size_override("font_size", 15)
	_sub_label.add_theme_color_override("font_color", SUB_COLOR)
	col.add_child(_sub_label)

	_build_arrow(layer)


func _build_arrow(layer: CanvasLayer) -> void:
	# Three flat polygons, added back to front: a dim halo, a soft outline, then
	# the chevron itself. No textures, and the outline scales with the chevron's
	# pulse for free.
	_ring = Polygon2D.new()
	_ring.polygon = _ring_points(ARROW_RADIUS + 9.0)
	_ring.color = Color(0, 0, 0, 0.28)
	layer.add_child(_ring)

	var outline := Polygon2D.new()
	outline.polygon = PackedVector2Array([
		Vector2(0, -ARROW_RADIUS - 4),
		Vector2(-17, 15),
		Vector2(17, 15),
	])
	outline.color = ARROW_EDGE
	layer.add_child(outline)

	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([
		Vector2(0, -ARROW_RADIUS),
		Vector2(-13, 11),
		Vector2(-5, 8),
		Vector2(5, 8),
		Vector2(13, 11),
	])
	_arrow.color = ARROW_COLOR
	layer.add_child(_arrow)


func _ring_points(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		return

	_check_condition(delta)
	_advance_if_ready()
	_update_gate()
	_update_panel()
	_update_arrow(delta)


func _stage_z(index: int) -> float:
	var z: float = STAGES[index]["z"]
	return z


func _stage_done() -> bool:
	return bool(_ready_flags.get(_stage, false))


## Informational steps have nothing to confirm, so they end at their gate.
## Action steps only end once the player has actually done the action.
func _stage_complete() -> bool:
	return _stage_done() or String(STAGES[_stage]["cond"]) == "none"


## Move on only when the step is complete and the player has reached the next
## gate. The old code advanced on distance alone, which skipped instructions.
func _advance_if_ready() -> void:
	while _stage + 1 < STAGES.size() and _stage_complete():
		if _player.global_position.z >= _stage_z(_stage + 1):
			break
		_stage += 1
		_enter_stage()


## Hold the player at the gate with a gentle backward current if they have not
## finished a step that could otherwise be skipped without moving. Collect steps
## are left open so the player can always swim back to a missed jellyfish.
func _update_gate() -> void:
	var push := 0.0
	var cond := String(STAGES[_stage]["cond"])
	var gate_needed := cond == "vertical" or cond == "boost"
	if gate_needed and not _stage_complete() and _stage + 1 < STAGES.size():
		var gate_z := _stage_z(_stage + 1) - 1.0
		push = clampf((gate_z - _player.global_position.z) * 8.0, 0.0, 6.0)
	_blocked = push > 0.25
	_player.set_tutorial_push(push)


func _check_condition(delta: float) -> void:
	if _stage_done():
		return
	var cond: String = STAGES[_stage]["cond"]
	match cond:
		"swim":
			if Input.is_action_pressed("ui_right"):
				_swim_time += delta
				if _swim_time >= 0.7:
					_ready_flags[_stage] = true
		"vertical":
			# One press of each direction, so holding up does not count as both.
			if Input.is_action_just_pressed("ui_up"):
				_pressed_up = true
			if Input.is_action_just_pressed("ui_down"):
				_pressed_down = true
			if _pressed_up and _pressed_down:
				_ready_flags[_stage] = true
		"boost":
			if Input.is_action_pressed("shift") and Input.is_action_pressed("ui_right"):
				_boost_time += delta
				if _boost_time >= 0.7:
					_ready_flags[_stage] = true
		"collect":
			if GameManager.jellyfish > _collected_at_stage_start:
				_ready_flags[_stage] = true
			else:
				# If the player already took every target, do not trap them.
				var high_only := String(STAGES[_stage]["mode"]) == "collectable_high"
				if _next_collectable(high_only) == null:
					_ready_flags[_stage] = true
		"none":
			pass


## Runs every frame, so anything that invalidates a theme override or a StyleBox is
## only touched when its value actually changes -- otherwise the whole card would
## re-rasterise 60 times a second for nothing.
func _update_panel() -> void:
	var done := _stage_done()
	var stage: Dictionary = STAGES[_stage]
	var msg: String = stage["done"] if done else stage["msg"]

	if _label.text != msg:
		_label.text = msg

	_step_label.text = "STEP %d / %d" % [_stage + 1, STAGES.size()]
	_bar.value = float(_stage + (1 if done else 0))

	var sub := ""
	if done:
		sub = "✓  done"
	elif _blocked:
		sub = "Finish this step to continue"
	if _sub_label.text != sub:
		_sub_label.text = sub
		_sub_label.add_theme_color_override("font_color",
			DONE_COLOR if done else (BLOCK_COLOR if _blocked else SUB_COLOR))

	if done == _panel_done:
		return
	_panel_done = done

	_panel_style.bg_color = PANEL_DONE_BG if done else PANEL_BG
	_panel_style.border_color = PANEL_DONE_BORDER if done else PANEL_BORDER
	_accent.color = ACCENT_DONE if done else ACCENT
	_bar_fill.bg_color = ACCENT_DONE if done else ACCENT


# ------------------------------------------------------------------ the arrow

## World-space point this stage is talking about.
##
## Collectable stages resolve to an actual live pickup; if the player has already
## taken them all the stage falls back to its literal point rather than leaving the
## arrow pointing at nothing.
func _resolve_target() -> Vector3:
	var stage: Dictionary = STAGES[_stage]
	var mode: String = stage["mode"]
	if mode == "collectable" or mode == "collectable_high":
		var node := _next_collectable(mode == "collectable_high")
		if node != null:
			return node.global_position
	var fallback: Vector3 = stage["target"]
	return fallback


## The nearest uncollected collectable. Prefers one ahead of the turtle, but
## falls back to the nearest one anywhere so a step never points at nothing.
##
## Collected ones queue_free() themselves, so group membership alone is enough to
## mean "not yet taken". "Ahead" is a lower z because the corridor swims toward -Z.
func _next_collectable(high_only: bool) -> Node3D:
	var best_ahead: Node3D = null
	var best_ahead_distance := INF
	var best_any: Node3D = null
	var best_any_distance := INF
	var from := _player.global_position
	for node in get_tree().get_nodes_in_group("collectable"):
		var candidate := node as Node3D
		if candidate == null or not is_instance_valid(candidate):
			continue
		if high_only and candidate.global_position.y < 3.4:
			continue
		var d := from.distance_to(candidate.global_position)
		if d < best_any_distance:
			best_any_distance = d
			best_any = candidate
		if candidate.global_position.z <= from.z + 1.0 and d < best_ahead_distance:
			best_ahead_distance = d
			best_ahead = candidate
	return best_ahead if best_ahead != null else best_any


func _update_arrow(delta: float) -> void:
	_pulse = fmod(_pulse + delta * 3.4, TAU)

	var cam := _player.get_node_or_null("Camera3D") as Camera3D
	if cam == null or _stage_done():
		_arrow.visible = false
		_ring.visible = false
		return

	var target := _resolve_target()
	var size := cam.get_viewport().get_visible_rect().size

	# Nothing to point at when the target is already comfortably on screen.
	if not cam.is_position_behind(target):
		var on_screen := cam.unproject_position(target)
		if on_screen.x > 0.0 and on_screen.x < size.x and on_screen.y > 0.0 and on_screen.y < size.y:
			_arrow.visible = false
			_ring.visible = false
			return

	var anchor := _player_screen(cam, size)
	var dir := _direction_to(cam, target, anchor, size)
	if dir == Vector2.ZERO:
		_arrow.visible = false
		_ring.visible = false
		return

	var rect := Rect2(Vector2(ARROW_MARGIN, ARROW_MARGIN), size - Vector2.ONE * (ARROW_MARGIN * 2.0))
	var pos := _ray_to_rect(anchor, dir, rect)

	var wobble := 1.0 + sin(_pulse) * 0.09
	# Polygon2D is drawn with its tip at (0, -radius), so rotating by t aims the
	# tip along (sin t, -cos t). Vector2.angle() gives a direction as
	# (cos t, sin t), hence the extra quarter turn. Without it the arrow sits at
	# right angles to whatever it is meant to be indicating.
	_arrow.position = pos
	_arrow.rotation = dir.angle() + PI * 0.5
	_arrow.scale = Vector2.ONE * wobble
	_ring.position = pos
	_ring.scale = Vector2.ONE * (1.0 + sin(_pulse) * 0.14)
	_ring.modulate = Color(1, 1, 1, 0.5 + 0.5 * sin(_pulse))
	_arrow.visible = true
	_ring.visible = true


func _player_screen(cam: Camera3D, size: Vector2) -> Vector2:
	var p := cam.unproject_position(_player.global_position)
	return Vector2(clampf(p.x, 0.0, size.x), clampf(p.y, 0.0, size.y))


## Screen-space direction to chase.
##
## In front of the camera both unprojected points are meaningful. Behind it they
## are not, so the camera-space x/y is used instead: those are the axes you have
## to turn towards, which is exactly what the pointer should show.
func _direction_to(cam: Camera3D, target: Vector3, anchor: Vector2, size: Vector2) -> Vector2:
	if cam.is_position_behind(target):
		var local := cam.global_transform.affine_inverse() * target
		return Vector2(local.x, local.y).normalized()

	var to := cam.unproject_position(target)
	var dir := to - anchor
	# Dead centre: the target is straight ahead, so there is no direction to show.
	if dir.length() < 6.0:
		return Vector2.ZERO
	return dir.normalized()


## March along `dir` from `origin` until it leaves `rect`.
func _ray_to_rect(origin: Vector2, dir: Vector2, rect: Rect2) -> Vector2:
	var t := INF
	if dir.x > 0.0001:
		t = minf(t, (rect.end.x - origin.x) / dir.x)
	elif dir.x < -0.0001:
		t = minf(t, (rect.position.x - origin.x) / dir.x)
	if dir.y > 0.0001:
		t = minf(t, (rect.end.y - origin.y) / dir.y)
	elif dir.y < -0.0001:
		t = minf(t, (rect.position.y - origin.y) / dir.y)
	if not is_finite(t) or t < 0.0:
		return origin
	return origin + dir * t


## Snapshot for tools/probe_tutorial.gd.
func debug_state() -> Dictionary:
	return {
		"stage": _stage,
		"done": _stage_done(),
		"complete": _stage_complete(),
		"blocked": _blocked,
		"message": _label.text if _label != null else "",
	}
