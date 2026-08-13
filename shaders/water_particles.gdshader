shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform vec4 bubble_color : source_color = vec4(0.6, 0.9, 1.0, 0.3);
uniform float fresnel_strength : hint_range(0.0, 5.0) = 2.0;
uniform float fresnel_power : hint_range(0.1, 5.0) = 3.0;
uniform float specular_sharpness : hint_range(0.0, 1.0) = 0.9;
uniform float opacity : hint_range(0.0, 1.0) = 0.25;
uniform float iridescence : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	vec3 view_dir = normalize(VIEW);
	float fresnel = pow(1.0 - max(dot(view_dir, NORMAL), 0.0), fresnel_power) * fresnel_strength;

	vec3 base = bubble_color.rgb;
	vec3 rim = mix(base, vec3(0.8, 0.95, 1.0), fresnel);

	// Iridescent rainbow shift
	float angle = dot(view_dir, NORMAL);
	vec3 rainbow = vec3(
		sin(angle * 3.0 + TIME * 0.5) * 0.5 + 0.5,
		sin(angle * 3.0 + TIME * 0.5 + 2.0) * 0.5 + 0.5,
		sin(angle * 3.0 + TIME * 0.5 + 4.0) * 0.5 + 0.5
	);

	vec3 final_color = mix(rim, rim + rainbow * 0.3, iridescence);

	ALBEDO = final_color;
	ALPHA = clamp(opacity + fresnel * 0.4, 0.0, 0.8);
	ROUGHNESS = 0.0;
	METALLIC = 0.5;
	SPECULAR = specular_sharpness;
	EMISSION = final_color * fresnel * 0.9;
}
