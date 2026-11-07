extends Node

const CORALS_SCENE := "res://assets/models/Corals with rock.blend"
const BUBBLES_SCENE := "res://scenes/effects/bubbles.tscn"
const ROCK_1_SCENE := "res://assets/models/blender/ROCK_1.blend"
const ROCK_2_SCENE := "res://assets/models/blender/ROCK_2.blend"
const ROCK_3_SCENE := "res://assets/models/blender/ROCK_3.blend"
const TURTLE_SCENE := "res://scenes/player/odysse.tscn"

## Decorative backdrop for the menu. Each row places one model in the 3D scene.
## Edit position (metres), rotation (degrees) and scale here to rearrange it.
## Add or remove rows to change how busy the background looks.
const BACKDROP: Array[Dictionary] = [
	{
		"scene": CORALS_SCENE, "name": "CoralsLeft",
		"position": Vector3(3.69, 2.39, -2.65),
		"rotation": Vector3(0, -118.57, 0),
		"scale": Vector3.ONE,
	},
	{
		"scene": CORALS_SCENE, "name": "CoralsRight",
		"position": Vector3(-5.44, 1.66, -3.67),
		"rotation": Vector3(0, -40.47, 0),
		"scale": Vector3(1.24, 0.68, 0.74),
	},
	{
		"scene": BUBBLES_SCENE, "name": "Bubbles",
		"position": Vector3(2.69, 0, -1.58),
		"rotation": Vector3.ZERO,
		"scale": Vector3.ONE,
	},
	{
		"scene": BUBBLES_SCENE, "name": "Bubbles2",
		"position": Vector3(-6.34, 0, -1.31),
		"rotation": Vector3.ZERO,
		"scale": Vector3.ONE,
	},
	{
		"scene": BUBBLES_SCENE, "name": "Bubbles3",
		"position": Vector3(-3.12, 0, -3.92),
		"rotation": Vector3.ZERO,
		"scale": Vector3.ONE,
	},
	{
		"scene": BUBBLES_SCENE, "name": "Bubbles4",
		"position": Vector3(0.82, 0, -5.15),
		"rotation": Vector3.ZERO,
		"scale": Vector3.ONE,
	},
	{
		"scene": ROCK_1_SCENE, "name": "Rock1",
		"position": Vector3(-1.34, 0, -4.87),
		"rotation": Vector3.ZERO,
		"scale": Vector3.ONE,
	},
	{
		"scene": ROCK_2_SCENE, "name": "Rock2",
		"position": Vector3(-6.44, 0, -0.45),
		"rotation": Vector3.ZERO,
		"scale": Vector3.ONE,
	},
	{
		"scene": ROCK_3_SCENE, "name": "Rock3",
		"position": Vector3(3.67, 0, 0.05),
		"rotation": Vector3.ZERO,
		"scale": Vector3.ONE,
	},
]

## The hero turtle. Kept separate because the menu animates it.
const HERO_POSITION := Vector3(-1.815, -0.601, -4.076)
const HERO_ROTATION := Vector3(5.55, 39.84, 4.61)

var _cam: Camera3D
var _cam_rest := Transform3D.IDENTITY
var _hero: Node3D
var _hero_rest := Transform3D.IDENTITY
var _t := 0.0
var _fade: ColorRect
var _intro_tween: Tween
var _transitioning := false

func _ready():
	_cam = get_node_or_null("Scene/Camera3D") as Camera3D
	if _cam:
		_cam_rest = _cam.transform
	_spawn_backdrop()
	_refresh_play_button()
	_style_primary_button()
	_build_title_accent()
	_build_fade()
	$Menu/PlayButton.pressed.connect(_on_play_pressed)
	$Menu/LevelsButton.pressed.connect(_on_levels_pressed)
	$Menu/ControlsButton.pressed.connect(_on_controls_pressed)
	$Menu/SettingsButton.pressed.connect(_on_settings_pressed)
	$Menu/QuitButton.pressed.connect(_on_quit_pressed)


## A slow drift keeps the 3D scene alive without pulling attention from the
## buttons, and the turtle gets a small idle bob and turn.
func _process(delta: float) -> void:
	_t += delta
	if _cam:
		var sway := Transform3D(
			Basis(Vector3.UP, sin(_t * 0.18) * 0.025), Vector3.ZERO)
		_cam.transform = _cam_rest * sway
	if _hero:
		_hero.transform = _hero_rest
		_hero.position.y += sin(_t * 0.9) * 0.035
		_hero.rotate_y(sin(_t * 0.3) * 0.12)

func _spawn_backdrop() -> void:
	var scene: Node3D = $Scene
	for item in BACKDROP:
		_add(scene, item["scene"], item["name"], item["position"],
			item["rotation"], item["scale"])

	var odysse: Node3D = load(TURTLE_SCENE).instantiate()
	odysse.name = "Odysse"
	odysse.position = HERO_POSITION
	odysse.rotation_degrees = HERO_ROTATION
	$Scene/CharacterBody3D.add_child(odysse)
	_hero = odysse
	_hero_rest = odysse.transform
	var anim_player := odysse.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player:
		var clip := anim_player.get_animation("IDLE")
		if clip:
			clip.loop = true
			anim_player.play("IDLE")

func _add(parent: Node3D, path: String, node_name: String,
		pos: Vector3, rot_degrees: Vector3, scale: Vector3) -> void:
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("Menu: failed to load " + path)
		return
	var instance: Node3D = packed.instantiate()
	instance.name = node_name
	instance.position = pos
	instance.rotation_degrees = rot_degrees
	instance.scale = scale
	parent.add_child(instance)

## A returning player should not have to replay the tutorial to reach their
## progress, so the main button becomes Continue once there is a save.
func _refresh_play_button() -> void:
	$Menu/PlayButton.text = "CONTINUE" if GameManager.has_progress() else "PLAY"


## One primary action: warm fill and a gold edge, with the other buttons left
## as quiet teal secondaries.
func _style_primary_button() -> void:
	var btn := $Menu/PlayButton as Button
	btn.add_theme_stylebox_override("normal", _primary_style(
		Color(0.05, 0.52, 0.58, 0.98), Color(1.0, 0.82, 0.38, 0.95), 12))
	btn.add_theme_stylebox_override("hover", _primary_style(
		Color(0.08, 0.62, 0.68, 1.0), Color(1.0, 0.88, 0.5, 1.0), 16))
	btn.add_theme_stylebox_override("pressed", _primary_style(
		Color(0.03, 0.38, 0.46, 1.0), Color(1.0, 0.82, 0.38, 0.9), 4))
	btn.add_theme_stylebox_override("focus", _primary_style(
		Color(0.08, 0.62, 0.68, 0.9), Color(1.0, 0.95, 0.8, 1.0), 10))
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.9, 1.0))


func _primary_style(bg: Color, border: Color, glow: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(14)
	style.set_border_width_all(3)
	style.border_color = border
	style.shadow_color = Color(1.0, 0.78, 0.35, 0.22)
	style.shadow_size = glow
	style.shadow_offset = Vector2(0, 4)
	return style


func _build_title_accent() -> void:
	var line := ColorRect.new()
	line.color = Color(1.0, 0.82, 0.38, 0.85)
	line.anchor_left = 0.5
	line.anchor_right = 0.5
	line.offset_left = -70.0
	line.offset_right = 70.0
	line.offset_top = 236.0
	line.offset_bottom = 239.0
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Menu.add_child(line)


## A short fade in on load and out before every action. It covers the scene
## change and gives the menu a softer entrance than a hard cut.
func _build_fade() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0.01, 0.05, 0.10, 1.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	$Menu.add_child(_fade)

	_intro_tween = create_tween()
	var step := _intro_tween.tween_property(_fade, "color:a", 0.0, 0.55)
	step.set_trans(Tween.TRANS_SINE)
	step.set_ease(Tween.EASE_OUT)
	_intro_tween.finished.connect(func(): _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE)


func _fade_then(action: Callable) -> void:
	if _transitioning or _fade == null:
		return
	_transitioning = true
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.22)
	await tween.finished
	action.call()


func _on_play_pressed() -> void:
	_fade_then(GameManager.continue_game)

func _on_levels_pressed() -> void:
	_fade_then(GameFlow.to_level_select)

func _on_controls_pressed() -> void:
	_fade_then(GameFlow.to_controls)

func _on_settings_pressed() -> void:
	_fade_then(GameFlow.to_settings)

func _on_quit_pressed() -> void:
	_fade_then(get_tree().quit)
