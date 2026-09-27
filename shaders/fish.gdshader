shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Fish shading for the low-poly CC0 Kenney fish models.
//
// These glbs ship a base-colour image at the relative path "Textures/colormap.png",
// which is not present in this repository, so Godot imports them with a dead
// texture reference and every fish renders as a flat untextured blob. Rather than
// hunt for the missing atlas, the colour is reconstructed procedurally from the
// mesh's own object-space coordinates, which is stable across both the small
// `fish.glb` and the larger `fish-large.glb`.
//
// Model space (both glbs, before the node's own scale):
//   x  -0.154 .. 0.154   head at -X, tail at +X
//   y  -0.080 .. 0.080   belly at -Y, back at +Y
//   z  -0.049 .. 0.049   width
//
// The result is real fish countershading (dark back, pale belly) with an
// optional stripe pattern, a translucent-looking tail/fin zone and a cool
// fresnel rim that reads correctly against the blue water.

uniform vec3 back_color : source_color = vec3(0.055, 0.145, 0.26);
uniform vec3 flank_color : source_color = vec3(0.13, 0.44, 0.60);
uniform vec3 belly_color : source_color = vec3(0.82, 0.90, 0.93);
uniform vec3 fin_color : source_color = vec3(0.42, 0.68, 0.80);
uniform vec3 rim_color : source_color = vec3(0.55, 0.88, 1.0);

// Silhouette landmarks in model units; keep in sync with the AABBs above.
uniform float half_height : hint_range(0.01, 0.5) = 0.08;
uniform float half_length : hint_range(0.05, 1.0) = 0.154;

// Where the fin membrane starts (1.0 = no separate fin zone).
uniform float fin_start : hint_range(0.3, 1.0) = 0.72;
uniform float fin_fade : hint_range(0.01, 0.4) = 0.16;

// Countershading contrast: 0 = flat, 1 = full back-to-belly ramp.
uniform float shade_strength : hint_range(0.0, 1.5) = 1.0;

uniform int stripes : hint_range(0, 12) = 0;
uniform float stripe_strength : hint_range(0.0, 1.0) = 0.35;
uniform float stripe_sharpness : hint_range(0.5, 8.0) = 2.5;

uniform float rim_strength : hint_range(0.0, 2.0) = 0.5;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

// A hint of emission keeps the fish readable in the dark, deep end of the
// corridor without washing out the scene.
uniform vec3 ambient_glow : source_color = vec3(0.18, 0.40, 0.52);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.10;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	// -1 at the belly, +1 along the back.
	float h = clamp(obj_pos.y / half_height, -1.0, 1.0);
	// 0 at the head, 1 at the tail.
	float t = clamp((obj_pos.x + half_length) / (half_length * 2.0), 0.0, 1.0);

	// Countershading: a three-stop ramp from the dark back down to the pale belly.
	float upper = smoothstep(0.0, 1.0, h);
	float lower = smoothstep(0.0, 1.0, -h);
	vec3 col = mix(flank_color, back_color, upper);
	col = mix(col, belly_color, lower * 0.85 * shade_strength);
	col = mix(flank_color, col, shade_strength);

	// Optional vertical bars, faded out over the head and tail.
	if (stripes > 0) {
		float phase = t * float(stripes) * 3.14159265;
		float bar = 0.5 + 0.5 * sin(phase);
		bar = pow(clamp(bar, 0.0, 1.0), stripe_sharpness);
		float mask = smoothstep(0.08, 0.28, t) * (1.0 - smoothstep(0.72, 0.95, t));
		col = mix(col, back_color * 1.25, bar * stripe_strength * mask);
	}

	// Fin membrane: the trailing third of the body turns pale and translucent.
	float fin = smoothstep(fin_start, fin_start + fin_fade, t);
	fin *= 0.35 + 0.65 * smoothstep(0.15, 0.85, abs(h));
	col = mix(col, fin_color, fin * 0.8);

	// A darker lateral line where the flanks meet, the way real fish are marked.
	float line = 1.0 - smoothstep(0.0, 0.22, abs(h - 0.05));
	col *= 1.0 - line * 0.16 * (1.0 - fin);

	ALBEDO = col;

	// Wet, slightly reflective body; fins are matte and translucent-looking.
	ROUGHNESS = mix(0.28, 0.62, fin);
	METALLIC = 0.06;
	SPECULAR = mix(0.55, 0.22, fin);

	// Cool fresnel rim: the single biggest cue that these are underwater fish.
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	RIM = rim_strength;
	RIM_TINT = 0.6;
	EMISSION = ambient_glow * glow_strength + rim_color * fres * rim_strength * 0.35;

	// A gentle vertical falloff so the belly catches less light than the back.
	ALBEDO *= 1.0 - 0.12 * (1.0 - (h * 0.5 + 0.5));
}
