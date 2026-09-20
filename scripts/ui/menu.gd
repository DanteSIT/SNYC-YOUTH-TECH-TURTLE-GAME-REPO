extends Node

const CORALS_SCENE := "res://assets/models/Corals with rock.blend"
const BUBBLES_SCENE := "res://scenes/effects/bubbles.tscn"
const ROCK_1_SCENE := "res://assets/models/blender/ROCK_1.blend"
const ROCK_2_SCENE := "res://assets/models/blender/ROCK_2.blend"
const ROCK_3_SCENE := "res://assets/models/blender/ROCK_3.blend"
const TURTLE_SCENE := "res://scenes/player/odysse.tscn"

func _ready():
	_spawn_backdrop()
	$Menu/PlayButton.pressed.connect(_on_play_pressed)
	$Menu/LevelsButton.pressed.connect(_on_levels_pressed)
	$Menu/ControlsButton.pressed.connect(_on_controls_pressed)
	$Menu/SettingsButton.pressed.connect(_on_settings_pressed)
	$Menu/QuitButton.pressed.connect(_on_quit_pressed)

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

func _on_play_pressed() -> void:
	GameManager.start_level(0)

func _on_levels_pressed() -> void:
	GameFlow.to_level_select()

func _on_controls_pressed() -> void:
	GameFlow.to_controls()

func _on_settings_pressed() -> void:
	GameFlow.to_settings()

func _on_quit_pressed() -> void:
	get_tree().quit()
