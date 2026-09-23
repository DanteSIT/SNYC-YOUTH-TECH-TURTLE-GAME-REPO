extends Node3D

@export_range(2, 12) var ray_count := 6
@export_range(4.0, 200.0) var level_length := 70.0
@export_range(2.0, 20.0) var height := 8.0
@export_range(5.0, 60.0) var cone_angle := 22.0
@export_range(5.0, 60.0) var range_distance := 30.0
@export_range(0.0, 10.0) var energy := 0.8
@export var light_color := Color(0.8, 0.92, 1.0)
@export_range(0.0, 10.0) var volumetric_fog_energy := 1.4
@export var first_beam_offset := 6.0

func _ready() -> void:
	_generate()


func _generate() -> void:
	for child in get_children():
		child.queue_free()
	if ray_count < 1 or level_length <= 0.0:
		return
	var usable := maxf(level_length - first_beam_offset * 2.0, 0.0)
	var step := usable / float(ray_count - 1)
	for i in ray_count:
		var light := SpotLight3D.new()
		light.name = "GodRay%d" % i
		light.position = Vector3(0, height, -level_length * 0.5 + first_beam_offset + step * i)
		light.rotation_degrees = Vector3(-90, 0, 0)
		light.spot_angle = cone_angle
		light.spot_range = range_distance
		light.spot_attenuation = 1.0
		light.light_color = light_color
		light.light_energy = energy
		light.light_specular = 0.0
		light.light_volumetric_fog_energy = volumetric_fog_energy
		light.shadow_enabled = false
		add_child(light)
