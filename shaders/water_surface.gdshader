shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec3 surface_color : source_color = vec3(0.4, 0.74, 0.84);
uniform vec3 crest_color : source_color = vec3(0.85, 0.97, 1.0);
uniform float wave_speed : hint_range(0.0, 5.0) = 1.1;
uniform float wave_scale : hint_range(0.1, 6.0) = 1.6;
uniform float wave_strength : hint_range(0.0, 1.0) = 0.5;
uniform float opacity : hint_range(0.0, 1.0) = 0.6;
uniform float sparkle : hint_range(0.0, 6.0) = 1.5;

varying vec3 world_pos;

float waves(vec2 p) {
	float v = 0.0;
	v += sin(p.x * 1.0 + TIME * wave_speed) * cos(p.y * 1.3 - TIME * 0.7);
	v += sin(p.x * 2.3 - TIME * 0.9) * cos(p.y * 1.9 + TIME * 0.6) * 0.6;
	v += sin(p.x * 0.6 + p.y * 1.1 + TIME * 0.5) * 0.4;
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * wave_scale;
	float w = waves(p);
	float dx = waves(p + vec2(0.25, 0.0)) - w;
	float dz = waves(p + vec2(0.0, 0.25)) - w;
	NORMAL = normalize(vec3(dx * wave_strength, 1.0, dz * wave_strength));
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 1.0;
	ALBEDO = surface_color;
	vec3 cam = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 V = normalize(cam - world_pos);
	float facing = clamp(abs(dot(NORMAL, V)), 0.0, 1.0);
	ALPHA = opacity * (0.35 + 0.65 * facing);
	float crest = pow(clamp(w * 0.5 + 0.5, 0.0, 1.0), 3.0);
	EMISSION = crest_color * crest * sparkle * 0.25;
}
