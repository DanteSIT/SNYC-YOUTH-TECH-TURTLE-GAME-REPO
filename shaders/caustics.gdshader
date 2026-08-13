shader_type spatial;
render_mode cull_back, diffuse_burley;

uniform vec3 base_color : source_color = vec3(0.76, 0.68, 0.5);
uniform vec3 caustic_color : source_color = vec3(0.45, 0.75, 0.95);
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.3;
uniform float caustic_scale : hint_range(0.05, 1.0) = 0.3;
uniform float caustic_speed : hint_range(0.0, 3.0) = 0.7;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float caustic(vec2 p, float t) {
	float v = 0.0;
	v += sin(p.x * 1.0 + t) * cos(p.y * 1.3 - t * 0.8);
	v += sin(p.x * 2.3 - t * 0.6) * cos(p.y * 1.9 + t * 0.5) * 0.7;
	v += sin(p.x * 0.7 + p.y * 1.1 + t * 0.4) * 0.5;
	return v;
}

void fragment() {
	ALBEDO = base_color;
	ROUGHNESS = 0.45;
	METALLIC = 0.0;
	SPECULAR = 1.0;
	vec2 p = world_pos.xz * caustic_scale;
	float t = TIME * caustic_speed;
	float c = caustic(p + vec2(t * 0.15, t * 0.1), t);
	c = clamp(c * 0.5 + 0.5, 0.0, 1.0);
	c = pow(c, 2.0);
	EMISSION = caustic_color * c * caustic_strength;
}
