extends Node

signal changed

const SAVE_PATH := "user://graphics.cfg"

const AA_OPTIONS: Array[Dictionary] = [
	{"name": "Off", "msaa": 0, "ssaa": 0, "taa": false},
	{"name": "FXAA", "msaa": 0, "ssaa": 1, "taa": false},
	{"name": "MSAA 2x", "msaa": 1, "ssaa": 0, "taa": false},
	{"name": "MSAA 4x", "msaa": 2, "ssaa": 0, "taa": false},
	{"name": "MSAA 8x", "msaa": 3, "ssaa": 0, "taa": false},
]

const SHADOW_OPTIONS: Array[Dictionary] = [
	{"name": "Low", "dir_size": 1024, "atlas": 1024, "soft": 0},
	{"name": "Medium", "dir_size": 2048, "atlas": 2048, "soft": 1},
	{"name": "High", "dir_size": 4096, "atlas": 4096, "soft": 2},
	{"name": "Ultra", "dir_size": 8192, "atlas": 8192, "soft": 3},
]

const SCALES: Array[float] = [0.5, 0.75, 1.0]

const PRESETS: Array[Dictionary] = [
	{"name": "Low", "aa": 0, "sharpen": 0.0, "scale": 0, "ssao": false, "ssr": false, "fog": true, "volumetric": false, "glow": false, "shadows": 0},
	{"name": "Medium", "aa": 1, "sharpen": 0.15, "scale": 1, "ssao": true, "ssr": false, "fog": true, "volumetric": false, "glow": true, "shadows": 1},
	{"name": "High", "aa": 2, "sharpen": 0.2, "scale": 2, "ssao": true, "ssr": false, "fog": true, "volumetric": true, "glow": true, "shadows": 2},
	{"name": "Ultra", "aa": 4, "sharpen": 0.3, "scale": 2, "ssao": true, "ssr": true, "fog": true, "volumetric": true, "glow": true, "shadows": 3},
]

var aa_index := 0
var sharpen := 0.0
var scale_index := 2
var shadows_index := 2
var ssao := true
var ssr := false
var fog := true
var volumetric := true
var glow := true
var preset_index := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_load_settings()
	apply()


func get_presets() -> Array[Dictionary]:
	return PRESETS


func get_aa_options() -> Array[Dictionary]:
	return AA_OPTIONS


func get_shadow_options() -> Array[Dictionary]:
	return SHADOW_OPTIONS


func get_scales() -> Array[float]:
	return SCALES


func get_preset_index() -> int:
	return preset_index


func get_aa_index() -> int:
	return aa_index


func get_sharpen() -> float:
	return sharpen


func get_scale_index() -> int:
	return scale_index


func get_shadows_index() -> int:
	return shadows_index


func get_ssao() -> bool:
	return ssao


func get_ssr() -> bool:
	return ssr


func get_fog() -> bool:
	return fog


func get_volumetric() -> bool:
	return volumetric


func get_glow() -> bool:
	return glow


func set_preset(index: int) -> void:
	if index >= 0 and index < PRESETS.size():
		var p: Dictionary = PRESETS[index]
		aa_index = int(p.aa)
		sharpen = float(p.sharpen)
		scale_index = int(p.scale)
		shadows_index = int(p.shadows)
		ssao = bool(p.ssao)
		ssr = bool(p.ssr)
		fog = bool(p.fog)
		volumetric = bool(p.volumetric)
		glow = bool(p.glow)
		preset_index = index
	else:
		preset_index = -1
	_save_settings()
	apply()


func set_aa(index: int) -> void:
	aa_index = clampi(index, 0, AA_OPTIONS.size() - 1)
	_after_change()


func set_sharpen(value: float) -> void:
	sharpen = clampf(value, 0.0, 1.0)
	_after_change()


func set_scale(index: int) -> void:
	scale_index = clampi(index, 0, SCALES.size() - 1)
	_after_change()


func set_shadows(index: int) -> void:
	shadows_index = clampi(index, 0, SHADOW_OPTIONS.size() - 1)
	_after_change()


func set_ssao(value: bool) -> void:
	ssao = value
	_after_change()


func set_ssr(value: bool) -> void:
	ssr = value
	_after_change()


func set_fog(value: bool) -> void:
	fog = value
	_after_change()


func set_volumetric(value: bool) -> void:
	volumetric = value
	_after_change()


func set_glow(value: bool) -> void:
	glow = value
	_after_change()


func apply() -> void:
	var aa: Dictionary = AA_OPTIONS[aa_index]
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", aa.msaa)
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/screen_space_aa", aa.ssaa)
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/use_taa", aa.taa)

	var vp: Viewport = get_tree().root
	vp.msaa_3d = (aa.msaa as Viewport.MSAA)
	vp.screen_space_aa = (aa.ssaa as Viewport.ScreenSpaceAA)
	vp.use_taa = bool(aa.taa)

	var scale := SCALES[scale_index]
	if scale < 1.0 or sharpen > 0.0:
		ProjectSettings.set_setting("rendering/scaling_3d/mode", 2)
		ProjectSettings.set_setting("rendering/scaling_3d/fsr_sharpness", sharpen)
	else:
		ProjectSettings.set_setting("rendering/scaling_3d/mode", 0)
	ProjectSettings.set_setting("rendering/scaling_3d/scale", scale)

	var sh: Dictionary = SHADOW_OPTIONS[shadows_index]
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", sh.dir_size)
	ProjectSettings.set_setting("rendering/lights_and_shadows/positional_shadow/atlas_size", sh.atlas)
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", sh.soft)
	ProjectSettings.set_setting("rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality", sh.soft)

	_apply_environment(get_tree().current_scene)
	changed.emit()


func _after_change() -> void:
	preset_index = _match_preset()
	_save_settings()
	apply()


func _match_preset() -> int:
	for i in PRESETS.size():
		var p: Dictionary = PRESETS[i]
		if int(p.aa) == aa_index and is_equal_approx(float(p.sharpen), sharpen) \
				and int(p.scale) == scale_index and bool(p.ssao) == ssao \
				and bool(p.ssr) == ssr and bool(p.fog) == fog \
				and bool(p.volumetric) == volumetric and bool(p.glow) == glow \
				and int(p.shadows) == shadows_index:
			return i
	return -1


func _apply_environment(node: Node) -> void:
	if node == null:
		return
	for child in node.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = child.environment
		if env == null:
			continue
		env.ssao_enabled = ssao
		env.ssr_enabled = ssr
		env.fog_enabled = fog
		env.volumetric_fog_enabled = volumetric
		env.glow_enabled = glow


func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment:
		var env: Environment = node.environment
		if env != null:
			env.ssao_enabled = ssao
			env.ssr_enabled = ssr
			env.fog_enabled = fog
			env.volumetric_fog_enabled = volumetric
			env.glow_enabled = glow


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	aa_index = clampi(int(cfg.get_value("graphics", "aa", 1)), 0, AA_OPTIONS.size() - 1)
	sharpen = clampf(float(cfg.get_value("graphics", "sharpen", 0.15)), 0.0, 1.0)
	scale_index = clampi(int(cfg.get_value("graphics", "scale", 2)), 0, SCALES.size() - 1)
	shadows_index = clampi(int(cfg.get_value("graphics", "shadows", 2)), 0, SHADOW_OPTIONS.size() - 1)
	ssao = bool(cfg.get_value("graphics", "ssao", true))
	ssr = bool(cfg.get_value("graphics", "ssr", false))
	fog = bool(cfg.get_value("graphics", "fog", true))
	volumetric = bool(cfg.get_value("graphics", "volumetric", true))
	glow = bool(cfg.get_value("graphics", "glow", true))
	preset_index = _match_preset()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "aa", aa_index)
	cfg.set_value("graphics", "sharpen", sharpen)
	cfg.set_value("graphics", "scale", scale_index)
	cfg.set_value("graphics", "shadows", shadows_index)
	cfg.set_value("graphics", "ssao", ssao)
	cfg.set_value("graphics", "ssr", ssr)
	cfg.set_value("graphics", "fog", fog)
	cfg.set_value("graphics", "volumetric", volumetric)
	cfg.set_value("graphics", "glow", glow)
	cfg.save(SAVE_PATH)
