shader_type spatial;
render_mode cull_disabled, depth_draw_never, diffuse_burley, specular_schlick_ggx;

// Seagrass / kelp blade.
//
// The kelp bed this replaced was 56 stacked BoxMeshes arranged as a staircase of
// cubes, so it read as a blocky green step rather than a plant. It is now a small
// rosette of alpha quads, which is both cheaper (16 draw calls instead of 56) and
// reads correctly from every angle.
//
// Two decisions worth keeping in mind when editing:
//
//   * ALPHA BLEND, not alpha scissor or alpha hash. Alpha scissor is a
//     BaseMaterial3D flag with no shader built-in equivalent, so a custom
//     ShaderMaterial cannot use it. ALPHA_HASH_SCALE does exist here and would
//     solve the sorting problem, but this project has no TAA
//     (Environment.use_taa is off in all 16 levels), so hashed alpha resolves to a
//     per-pixel dither that shimmers badly against a moving camera. Plain blending
//     with depth_draw_never, relying on Godot's back-to-front transparent sort, is
//     the lesser evil for thin blades standing on opaque sand.
//   * The bend is computed in WORLD space and then pushed back into local space
//     with inverse(MODEL_MATRIX). Every blade in a bed is instanced at a
//     different yaw, so bending along local X would make half of them lean along
//     one corridor wall and the other half across it.

uniform sampler2D albedo_tex : source_color, repeat_disable, filter_linear_mipmap_anisotropic;

// Root-to-tip tint. The sprite is already green; these shape the gradient and let
// one shader cover pale shallow seagrass and deep kelp.
uniform vec3 tint_dark : source_color = vec3(0.28, 0.42, 0.24);
uniform vec3 tint_light : source_color = vec3(0.82, 0.98, 0.55);
uniform vec3 emission_tint : source_color = vec3(0.18, 0.42, 0.30);
uniform float emission_energy : hint_range(0.0, 1.0) = 0.16;

uniform float sway_speed : hint_range(0.0, 4.0) = 0.85;
uniform float sway_amount : hint_range(0.0, 0.5) = 0.085;
uniform float blade_height : hint_range(0.1, 8.0) = 1.0;

varying float v_height;


void vertex() {
	// 0 at the root, 1 at the tip, from the LOCAL y so every quad in the rosette
	// bends about its own base no matter how tall it is.
	float h = clamp(VERTEX.y / max(blade_height, 0.001), 0.0, 1.0);
	v_height = h;

	// Bend scales with the square of the height, so the root stays planted in the
	// sand and only the upper half of the blade actually moves.
	float bend = h * h * sway_amount;

	// Phase is taken from world position, otherwise every blade in the bed
	// oscillates in lockstep and the whole patch reads as one rigid object.
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = world.x * 0.7 + world.z * 0.9;
	float s = sin(TIME * sway_speed + phase) * 0.68
			+ sin(TIME * sway_speed * 1.73 + phase * 1.31) * 0.32;

	vec3 world_bend = vec3(s * bend, 0.0, s * bend * 0.62);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(world_bend, 0.0)).xyz;
}


void fragment() {
	vec4 tex = texture(albedo_tex, UV);

	// Square the ramp so the root stays dark and saturated and the tips are the
	// only part that catches light, which is what sells it as depth rather than
	// a flat green cut-out. A dark base also hides the fact that the quads in a
	// tuft are not perfectly sorted against each other.
	vec3 tint = mix(tint_dark, tint_light, v_height * v_height);
	vec3 col = tex.rgb * tint;

	ALBEDO = col;
	// A little self-illumination so blades deep in the fog do not go to black.
	EMISSION = emission_tint * emission_energy;
	ROUGHNESS = 0.76;
	SPECULAR = 0.22;
	METALLIC = 0.0;
	ALPHA = tex.a;
}
