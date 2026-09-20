shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 beam_color : source_color = vec4(1.0, 0.94, 0.82, 1.0);
uniform float intensity : hint_range(0.0, 8.0) = 2.2;
uniform float shaft_height : hint_range(1.0, 20.0) = 7.0;
uniform float top_width : hint_range(0.2, 1.6) = 0.85;
uniform float bottom_width : hint_range(0.1, 1.2) = 0.5;
uniform float shimmer_speed : hint_range(0.0, 3.0) = 0.45;
uniform float shimmer_amount : hint_range(0.0, 1.0) = 0.6;

varying vec2 v_uv;

void vertex() {
	// billboard: face the camera, keep model scale + position (anchor at surface)
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	mat3 cam_basis = mat3(INV_VIEW_MATRIX);
	mat4 world = mat4(
		vec4(cam_basis[0] * s.x, 0.0),
		vec4(cam_basis[1] * s.y, 0.0),
		vec4(cam_basis[2] * s.z, 0.0),
		vec4(MODEL_MATRIX[3].xyz, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	v_uv = UV;
}

void fragment() {
	// v_t: 1 at the surface, 0 at the tip
	float v_t = 1.0 - v_uv.y;
	float v_x = v_uv.x * 2.0 - 1.0;

	// edge wobble (refraction through moving surface)
	float wob = sin(v_t * 5.0 - TIME * 0.7) * 0.05 + sin(v_t * 9.0 - TIME * 0.45) * 0.035;

	// tapered half-width, soft gaussian beam (core + halo)
	float half_w = mix(bottom_width, top_width, v_t) * 0.5;
	float sp = (v_x + wob) / half_w;
	float core = exp(-8.0 * sp * sp);
	float halo = exp(-2.0 * sp * sp);
	float beam = mix(halo, core, 0.6);

	// fade toward the tip; brightest just under the surface
	float vert = pow(v_t, 1.6);

	// travelling light bands (caustic shimmer)
	float band = sin(v_t * 10.0 - TIME * shimmer_speed * 2.4) * 0.5 + 0.5;
	band = smoothstep(0.28, 0.82, band);
	float shimmer = mix(1.0, band, shimmer_amount);

	float a = beam * vert * shimmer;
	if (a < 0.012) {
		discard;
	}
	ALBEDO = beam_color.rgb * intensity * a;
	ALPHA = 1.0;
	EMISSION = ALBEDO;
}
