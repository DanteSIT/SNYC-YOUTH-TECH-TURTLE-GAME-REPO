shader_type canvas_item;
render_mode unshaded;

// Screen-space underwater grade + refraction wobble + caustic light + vignette.
// Applied as a full-screen ColorRect overlay (CanvasLayer 0) so it sits under the HUD.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform vec3 shallow_tint : source_color = vec3(0.62, 0.92, 1.0);
uniform vec3 deep_tint : source_color = vec3(0.10, 0.42, 0.72);
uniform vec3 shadow_tint : source_color = vec3(0.05, 0.24, 0.42);

uniform float tint_strength : hint_range(0.0, 1.0) = 0.34;
uniform float depth : hint_range(0.0, 1.0) = 0.35;
uniform float wobble_amount : hint_range(0.0, 0.02) = 0.0032;
uniform float wobble_speed : hint_range(0.0, 4.0) = 0.9;
uniform float caustic_strength : hint_range(0.0, 1.5) = 0.16;
uniform float caustic_scale : hint_range(0.2, 8.0) = 2.2;
uniform float caustic_speed : hint_range(0.0, 2.0) = 0.22;
uniform float chroma : hint_range(0.0, 6.0) = 1.3;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.72;
uniform float vignette_softness : hint_range(0.05, 1.0) = 0.48;
uniform float brightness : hint_range(0.5, 1.5) = 0.95;
uniform float saturation : hint_range(0.0, 2.0) = 1.08;

// Grade shape. The scene arrives here already tonemapped, so this pass is the
// only place the image can be given a real black point: the flat sky ambient and
// the volumetric fog emission lift every pixel off zero, and without a black
// point the whole frame reads as milky no matter how the environment is tuned.
uniform float contrast : hint_range(0.5, 2.0) = 1.16;
uniform float black_point : hint_range(0.0, 0.25) = 0.05;

// ridged interference -> caustic veins (4 trig; the third field was dropped
// because this runs on every pixel of a full-screen pass)
float caustic(vec2 p, float t) {
	vec2 w1 = vec2(sin(p.x * 1.0 + t), cos(p.y * 1.3 - t * 0.8));
	vec2 w2 = vec2(sin(p.x * 2.3 - t * 0.6 + p.y * 0.7), cos(p.y * 1.9 + t * 0.5));
	return w1.x * w1.y + w2.x * w2.y * 0.7;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME * wobble_speed;

	// --- refraction wobble: layered sines, stronger toward the edges ---
	vec2 c = uv - 0.5;
	float edge = length(c) * 1.35;
	vec2 wob = vec2(
		sin(uv.y * 14.0 + t * 1.7) + sin(uv.y * 27.0 - t * 1.1) * 0.5,
		cos(uv.x * 12.0 - t * 1.3) + cos(uv.x * 23.0 + t * 0.9) * 0.5);
	wob *= wobble_amount * (0.45 + edge);

	// --- chromatic aberration, scaled by distance from centre ---
	vec2 ca_off = c * chroma * 0.0016 * (0.25 + edge);
	vec3 col;
	col.r = texture(screen_tex, uv + wob + ca_off).r;
	col.g = texture(screen_tex, uv + wob).g;
	col.b = texture(screen_tex, uv + wob - ca_off).b;

	// --- caustic light dancing across the frame (procedural, no texture) ---
	// One evaluation with the fine layer folded out of the same field: this is a
	// full-screen pass, so the second caustic field was pure cost.
	vec2 cuv = uv * caustic_scale + vec2(t * caustic_speed, t * caustic_speed * 0.6);
	float c1 = caustic(cuv, t);
	float v1 = pow(clamp(c1 * 0.5 + 0.5, 0.0, 1.0), 3.0);
	float caust = v1 * (0.85 + 0.35 * sin(c1 * 8.0 + t * 1.7));
	col += shallow_tint * caust * caustic_strength * (1.0 - depth * 0.65);

	// --- underwater colour grade (mix toward tint, deepen shadows) ---
	// The tint is applied as a straight multiply. It used to be scaled by 1.15,
	// which pushed blue past 1.0 and quietly re-brightened everything the grade
	// was meant to be pulling down.
	vec3 tint = mix(shallow_tint, deep_tint, depth);
	col = mix(col, col * tint, tint_strength);

	// Reclaim the black point, then build contrast around mid grey. Without this
	// the flat ambient term means the darkest thing in frame is still a pale blue.
	col = max(col - vec3(black_point), vec3(0.0)) / max(1.0 - black_point, 0.001);
	col = (col - 0.5) * contrast + 0.5;

	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(col, mix(col, shadow_tint, 0.55), clamp(1.0 - lum, 0.0, 1.0) * (0.18 + depth * 0.4));
	col *= brightness;
	col = mix(vec3(lum), col, saturation);

	// --- vignette ---
	float v = smoothstep(0.95, vignette_softness, length(c) * 1.42);
	col *= mix(1.0, v, vignette_strength);

	// --- faint animated grain so the water never reads as flat ---
	col += (hash(uv * 900.0 + fract(t)) - 0.5) * 0.012;

	COLOR = vec4(col, 1.0);
}
