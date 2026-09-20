extends Node

signal changed

const SAVE_PATH := "user://audio.cfg"

const BUS_MUSIC := "Music"
const BUS_AMBIENCE := "Ambience"
const BUS_SFX := "SFX"

const MENU_MUSIC := preload("res://assets/audio/menu sound turtle.mp3")
const LEVEL_MUSIC := preload("res://assets/audio/underwater music.mp3")
const TUTORIAL_MUSIC := preload("res://assets/audio/tutorialmusic.mp3")

var music_on := true
var music_volume := 0.7
var ambience_on := true
var ambience_volume := 0.6
var sfx_volume := 0.9

var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_player = AudioStreamPlayer.new()
	_player.bus = BUS_MUSIC
	_player.stream = LEVEL_MUSIC
	_player.volume_db = 0.0
	add_child(_player)
	get_tree().node_added.connect(_on_node_added)
	get_tree().scene_changed.connect(_on_scene_changed)
	_load_settings()
	_apply()
	_update_music.call_deferred()


func get_music_on() -> bool:
	return music_on


func get_music_volume() -> float:
	return music_volume


func get_ambience_on() -> bool:
	return ambience_on


func get_ambience_volume() -> float:
	return ambience_volume


func get_sfx_volume() -> float:
	return sfx_volume


func set_music_on(value: bool) -> void:
	music_on = value
	_save_and_apply()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_save_and_apply()


func set_ambience_on(value: bool) -> void:
	ambience_on = value
	_save_and_apply()


func set_ambience_volume(value: float) -> void:
	ambience_volume = clampf(value, 0.0, 1.0)
	_save_and_apply()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_save_and_apply()


func _save_and_apply() -> void:
	_save_settings()
	_apply()
	changed.emit()


func _ensure_buses() -> void:
	for name in [BUS_MUSIC, BUS_AMBIENCE, BUS_SFX]:
		if AudioServer.get_bus_index(name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, name)


func _on_node_added(node: Node) -> void:
	if node is AudioStreamPlayer:
		if node.name == "Ambience":
			node.bus = BUS_AMBIENCE
		elif node.name == "Music":
			node.bus = BUS_MUSIC


func _on_scene_changed() -> void:
	_update_music()


func _update_music() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var path: String = scene.scene_file_path
	var track: AudioStream = LEVEL_MUSIC
	if "menu" in path or "splash" in path or "level_select" in path \
			or "controls" in path or "settings" in path \
			or "game_over" in path or "level_complete" in path:
		track = MENU_MUSIC
	elif "tutorial" in path:
		track = TUTORIAL_MUSIC
	if music_on:
		if _player.stream != track:
			_player.stream = track
		if not _player.playing:
			_player.play()
	else:
		_player.stop()


func _apply() -> void:
	var music_idx := AudioServer.get_bus_index(BUS_MUSIC)
	if music_idx >= 0:
		AudioServer.set_bus_mute(music_idx, not music_on)
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(maxf(music_volume, 0.001)))
	var amb_idx := AudioServer.get_bus_index(BUS_AMBIENCE)
	if amb_idx >= 0:
		AudioServer.set_bus_mute(amb_idx, not ambience_on)
		AudioServer.set_bus_volume_db(amb_idx, linear_to_db(maxf(ambience_volume, 0.001)))
	var sfx_idx := AudioServer.get_bus_index(BUS_SFX)
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(maxf(sfx_volume, 0.001)))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	music_on = bool(cfg.get_value("audio", "music_on", true))
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", 0.7)), 0.0, 1.0)
	ambience_on = bool(cfg.get_value("audio", "ambience_on", true))
	ambience_volume = clampf(float(cfg.get_value("audio", "ambience_volume", 0.6)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", 0.9)), 0.0, 1.0)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "ambience_on", ambience_on)
	cfg.set_value("audio", "ambience_volume", ambience_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.save(SAVE_PATH)
