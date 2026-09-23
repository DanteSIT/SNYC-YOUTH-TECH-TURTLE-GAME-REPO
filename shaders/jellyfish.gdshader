shader_type spatial;
render_mode cull_back, blend_mix, depth_draw_opaque, shadows_disabled;

uniform vec4 base_color : source_color = vec4(0.85, 0.45, 0.9, 0.65);
uniform vec3 glow_color : source_color = vec3(1.0, 0.7, 1.0);
uniform float glow_strength : hint_range(0.0, 5.0) = 1.8;
uniform float pulse_speed : hint_range(0.0, 5.0) = 1.2;
uniform float pulse_amplitude : hint_range(0.0, 0.25) = 0.07;
uniform float pulse_radial_freq : hint_range(0.5, 20.0) = 4.0;
uniform float fresnel_power : hint_range(0.0, 8.0) = 2.5;

varying float pulse;

void vertex() {
	float t = TIME * pulse_speed;
	float dist = length(VERTEX.xz);
	float wave = sin(dist * pulse_radial_freq - t * 2.0);
	float amt = wave * pulse_amplitude;
	VERTEX.y += amt;
	if (dist > 0.001) {
		VERTEX.xz += (VERTEX.xz / dist) * amt * 0.4;
	}
	pulse = wave;
}

void fragment() {
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);
	ALBEDO = base_color.rgb;
	ALPHA = base_color.a;
	ROUGHNESS = 0.4;
	SPECULAR = 0.3;
	float g = 0.5 + 0.5 * pulse;
	EMISSION = glow_color * glow_strength * (0.35 + fresnel * 0.9 + g * 0.4);
}
