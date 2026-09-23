shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, repeat_enable;
uniform float tile : hint_range(0.5, 40.0) = 4.0;
uniform vec3 tint : source_color = vec3(1.0, 0.98, 0.92);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(abs(NORMAL));
	n /= (n.x + n.y + n.z);
	vec3 x = texture(albedo_tex, world_pos.yz * tile).rgb;
	vec3 y = texture(albedo_tex, world_pos.xz * tile).rgb;
	vec3 z = texture(albedo_tex, world_pos.xy * tile).rgb;
	vec3 col = x * n.x + y * n.y + z * n.z;
	ALBEDO = col * tint;
	ROUGHNESS = 0.95;
	SPECULAR = 1.0;
}
