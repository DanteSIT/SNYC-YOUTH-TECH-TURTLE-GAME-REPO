extends Node

signal settings_changed

const REFRESH_INTERVAL := 0.25
const CPU_REFRESH_INTERVAL := 1.0
const GPU_REFRESH_INTERVAL := 1.0
const CLK_TCK := 100.0
const FPS_CAPS: Array[int] = [30, 60, 90, 120, 0]
const SAVE_PATH := "user://debug_stats.cfg"

var _label: Label
var _panel: PanelContainer
var _timer := 0.0
var _cpu_timer := 0.0
var _gpu_timer := 0.0
var _shown := true
var _fps_cap_index := 4
var _vsync_enabled := false

var _fps_min: float = 1.0e9
var _fps_sum := 0.0
var _fps_samples := 0

var _cpu_ticks := 0
var _cpu_wall := 0.0
var _sys_ticks := 0
var _sys_idle := 0
var _cpu_pct := 0.0
var _sys_pct := 0.0

var _nvidia_path := ""
var _gpu_util := 0.0
var _gpu_mem_used := 0.0
var _gpu_mem_total := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_load_settings()
	for path in ["/usr/bin/nvidia-smi", "/usr/local/bin/nvidia-smi", "/bin/nvidia-smi"]:
		if FileAccess.file_exists(path):
			_nvidia_path = path
			break
	if not _nvidia_path.is_empty():
		_query_gpu()
	_update_cpu_samples()
	_label.text = _build_text()
	_position_panel.call_deferred()


func _process(delta: float) -> void:
	_timer += delta
	_gpu_timer += delta
	_cpu_timer += delta
	if _cpu_timer >= CPU_REFRESH_INTERVAL:
		_cpu_timer = 0.0
		_update_cpu_samples()
	if _timer < REFRESH_INTERVAL:
		return
	_timer = 0.0
	if _gpu_timer >= GPU_REFRESH_INTERVAL:
		_gpu_timer = 0.0
		if not _nvidia_path.is_empty():
			_query_gpu()
	_label.text = _build_text()
	_position_panel()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F3:
			_shown = not _shown
			_panel.visible = _shown
			_label.visible = _shown
		KEY_F4:
			set_fps_cap_index((_fps_cap_index + 1) % FPS_CAPS.size())
		KEY_F5:
			set_vsync_enabled(not _vsync_enabled)


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_shown = false
		_panel.visible = false
		_label.visible = false


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_fps_cap_index = clampi(int(cfg.get_value("stats", "fps_cap_index", 4)), 0, FPS_CAPS.size() - 1)
		_vsync_enabled = bool(cfg.get_value("stats", "vsync", false))
	Engine.max_fps = FPS_CAPS[_fps_cap_index]
	_apply_vsync(_vsync_enabled)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "fps_cap_index", _fps_cap_index)
	cfg.set_value("stats", "vsync", _vsync_enabled)
	cfg.save(SAVE_PATH)


func _apply_vsync(enabled: bool) -> void:
	var mode := DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)


func get_fps_caps() -> Array[int]:
	return FPS_CAPS


func get_fps_cap_index() -> int:
	return _fps_cap_index


func set_fps_cap_index(index: int) -> void:
	_fps_cap_index = clampi(index, 0, FPS_CAPS.size() - 1)
	Engine.max_fps = FPS_CAPS[_fps_cap_index]
	_save_settings()
	settings_changed.emit()


func is_vsync_enabled() -> bool:
	return _vsync_enabled


func set_vsync_enabled(enabled: bool) -> void:
	_vsync_enabled = enabled
	_apply_vsync(_vsync_enabled)
	_save_settings()
	settings_changed.emit()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DebugStatsLayer"
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_panel_input)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.border_color = Color(1, 1, 1, 0.15)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	_panel = panel

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.65, 1.0, 0.7))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_label)


func _position_panel() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_panel.position = Vector2(maxf(0.0, vp_size.x - _panel.size.x - 10.0), 10.0)


func _build_text() -> String:
	var fps := Engine.get_frames_per_second()
	_fps_min = mini(_fps_min, float(fps))
	_fps_samples += 1
	_fps_sum += float(fps)
	var fps_avg := _fps_sum / float(_fps_samples)

	var frame_ms := 1000.0 / maxf(float(fps), 0.001)
	var ram := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)

	var lines := PackedStringArray()
	lines.append("FPS  %3d  avg %.1f  min %.1f" % [fps, fps_avg, _fps_min])
	lines.append("FRAME  %.2f ms" % frame_ms)
	lines.append("CPU  proc %.0f%%  sys %.0f%%" % [_cpu_pct, _sys_pct])
	lines.append("RAM  %.0f MB" % ram)
	lines.append("VRAM  %.0f MB" % vram)
	if not _nvidia_path.is_empty():
		lines.append("GPU  util %.0f%%  mem %.1f/%.1f GB" % [
			_gpu_util, _gpu_mem_used / 1024.0, _gpu_mem_total / 1024.0])
	else:
		lines.append("GPU  util N/A")
	return "\n".join(lines)


func _update_cpu_samples() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var t := _read_proc_ticks()
	var s := _read_sys_cpu()
	if _cpu_ticks > 0:
		var dt := now - _cpu_wall
		if dt > 0.0:
			_cpu_pct = float(t - _cpu_ticks) / (dt * CLK_TCK) * 100.0
		var d_total := s.x - _sys_ticks
		var d_idle := s.y - _sys_idle
		if d_total > 0:
			_sys_pct = clampf(float(d_total - d_idle) / float(d_total) * 100.0, 0.0, 100.0)
	_cpu_ticks = t
	_cpu_wall = now
	_sys_ticks = s.x
	_sys_idle = s.y


func _read_proc_ticks() -> int:
	var out: Array = []
	var ret := OS.execute("cat", ["/proc/%d/stat" % OS.get_process_id()], out)
	if ret != 0 or out.is_empty():
		return 0
	var content := str(out[0])
	var idx := content.rfind(")")
	if idx == -1:
		return 0
	var parts := content.substr(idx + 2).split(" ", false)
	if parts.size() <= 13:
		return 0
	return parts[11].to_int() + parts[12].to_int()


func _read_sys_cpu() -> Vector2i:
	var out: Array = []
	var ret := OS.execute("cat", ["/proc/stat"], out)
	if ret != 0 or out.is_empty():
		return Vector2i.ZERO
	var line := str(out[0]).split("\n")[0]
	if not line.begins_with("cpu "):
		return Vector2i.ZERO
	var parts := line.split(" ", false)
	var total := 0
	var idle := 0
	for i in range(1, parts.size()):
		var v := parts[i].to_int()
		total += v
		if i == 4 or i == 5:
			idle += v
	return Vector2i(total, idle)


func _query_gpu() -> void:
	var output: Array = []
	var ret := OS.execute(_nvidia_path,
		["--query-gpu=utilization.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"],
		output)
	if ret != 0 or output.is_empty():
		return
	var parts := str(output[0]).strip_edges().split(",")
	if parts.size() >= 3:
		_gpu_util = parts[0].strip_edges().to_float()
		_gpu_mem_used = parts[1].strip_edges().to_float()
		_gpu_mem_total = parts[2].strip_edges().to_float()
