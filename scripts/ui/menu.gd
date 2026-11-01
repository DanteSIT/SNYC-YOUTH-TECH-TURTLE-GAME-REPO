extends Node

const CORALS_SCENE := "res://assets/models/Corals with rock.blend"
const BUBBLES_SCENE := "res://scenes/effects/bubbles.tscn"
const ROCK_1_SCENE := "res://assets/models/blender/ROCK_1.blend"
const ROCK_2_SCENE := "res://assets/models/blender/ROCK_2.blend"
const ROCK_3_SCENE := "res://assets/models/blender/ROCK_3.blend"
const TURTLE_SCENE := "res://scenes/player/odysse.tscn"

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
	_add(scene, CORALS_SCENE, "Corals with rock", _tf(-0.47826278, -2.9802322e-08, -0.8782168, 7.450581e-09, 1, 2.9802322e-08, 0.87821686, -7.450581e-09, -0.47826278, 3.692937, 2.3853414, -2.6499658))
	_add(scene, CORALS_SCENE, "Corals with rock2", _tf(0.94599766, -9.110099e-09, -0.4807648, 9.265032e-09, 0.67806995, 2.2074751e-08, 0.8071305, 1.8732178e-08, 0.56348056, -5.4397006, 1.6604564, -3.669231))
	_add(scene, BUBBLES_SCENE, "Bubbles", Transform3D(Basis.IDENTITY, Vector3(2.694817, 2.3841858e-07, -1.582283)))
	_add(scene, BUBBLES_SCENE, "Bubbles2", Transform3D(Basis.IDENTITY, Vector3(-6.3408275, 2.3841858e-07, -1.3145547)))
	_add(scene, BUBBLES_SCENE, "Bubbles3", Transform3D(Basis.IDENTITY, Vector3(-3.1165552, 2.3841858e-07, -3.9216337)))
	_add(scene, BUBBLES_SCENE, "Bubbles4", Transform3D(Basis.IDENTITY, Vector3(0.8210559, 2.3841858e-07, -5.152159)))
	_add(scene, ROCK_1_SCENE, "ROCK_1", Transform3D(Basis.IDENTITY, Vector3(-1.3391193, 0, -4.8715563)))
	_add(scene, ROCK_2_SCENE, "ROCK_2", Transform3D(Basis.IDENTITY, Vector3(-6.4432864, 0, -0.44777536)))
	_add(scene, ROCK_3_SCENE, "ROCK_3", Transform3D(Basis.IDENTITY, Vector3(3.6657772, 0, 0.05233884)))

	var odysse: Node3D = load(TURTLE_SCENE).instantiate()
	odysse.name = "Odysse"
	odysse.transform = _tf(0.77030194, -7.968338e-09, 0.63767946, 0.08004391, 0.9920905, -0.096691266, -0.6326357, 0.12552372, 0.76420945, -1.8149792, -0.60145223, -4.0761976)
	$Scene/CharacterBody3D.add_child(odysse)
	_hero = odysse
	_hero_rest = odysse.transform
	var anim_player := odysse.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player:
		var clip := anim_player.get_animation("IDLE")
		if clip:
			clip.loop = true
			anim_player.play("IDLE")

func _add(parent: Node3D, path: String, node_name: String, transform: Transform3D) -> void:
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("Menu: failed to load " + path)
		return
	var instance: Node3D = packed.instantiate()
	instance.name = node_name
	instance.transform = transform
	parent.add_child(instance)

func _tf(xx, yx, zx, xy, yy, zy, xz, yz, zz, ox, oy, oz) -> Transform3D:
	return Transform3D(Basis(Vector3(xx, xy, xz), Vector3(yx, yy, yz), Vector3(zx, zy, zz)), Vector3(ox, oy, oz))

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
