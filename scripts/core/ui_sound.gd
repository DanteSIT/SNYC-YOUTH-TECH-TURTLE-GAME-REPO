extends Node

## Tiny generated hover and click blips for every Button in the game.
##
## The tones are synthesised at startup, so UI feedback needs no extra audio
## files. Buttons are wired automatically as they enter the tree.

const RATE := 22050
const VOICES := 4

var _hover: AudioStreamWAV
var _click: AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hover = _tone(PackedFloat32Array([880.0, 1320.0]), 0.055, 0.16)
	_click = _tone(PackedFloat32Array([520.0, 780.0]), 0.095, 0.24)
	for _i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)
	get_tree().node_added.connect(_on_node_added)
	_attach_existing(get_tree().root)


func _on_node_added(node: Node) -> void:
	if node is Button:
		_attach.call_deferred(node)


func _attach_existing(node: Node) -> void:
	if node is Button:
		_attach(node)
	for child in node.get_children():
		_attach_existing(child)


func _attach(button: Button) -> void:
	if not is_instance_valid(button) or button.has_meta("ui_sound"):
		return
	button.set_meta("ui_sound", true)
	button.mouse_entered.connect(_on_hover.bind(button))
	button.pressed.connect(_on_pressed.bind(button))


func _on_hover(button: Button) -> void:
	if button.disabled or not button.is_visible_in_tree():
		return
	_play(_hover)


func _on_pressed(button: Button) -> void:
	if button.disabled:
		return
	_play(_click)


func _play(stream: AudioStreamWAV) -> void:
	if _players.is_empty():
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.play()


## A short two-note blip with a fast attack and exponential decay.
func _tone(freqs: PackedFloat32Array, duration: float, volume: float) -> AudioStreamWAV:
	var frames := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / RATE
		var attack := minf(1.0, t / 0.004)
		var decay := exp(-t * 22.0)
		var release := clampf((duration - t) / 0.012, 0.0, 1.0)
		var sample := 0.0
		for f in freqs:
			sample += sin(TAU * f * t)
		sample = sample / freqs.size() * attack * decay * release * volume
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
