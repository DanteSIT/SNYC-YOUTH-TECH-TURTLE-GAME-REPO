shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, fog_disabled;

// Parallax backdrop band. Uses a seamless tileable texture with a per-band
// UV offset so neighbouring bands never line up and reveal the same repeating
// feature. The band plane covers the full level length; the texture samples
// once across it, and the offset shifts which part of the seamless texture
// each band shows.

uniform sampler2D texture_albedo : source_color, filter_linear, repeat_enable;
uniform float offset_x : hint_range(0.0, 1.0) = 0.0;
uniform float offset_y : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV + vec2(offset_x, offset_y);
	vec4 albedo = texture(texture_albedo, uv);
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
	EMISSION = albedo.rgb;
}
