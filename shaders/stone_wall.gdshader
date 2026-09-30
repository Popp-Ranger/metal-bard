shader_type spatial;
render_mode diffuse_toon, specular_toon; // cel shading
// Mur de pierre procédural (briques) + découpe « façon Diablo » :
// les murs situés entre la caméra et le héros sont tramés pour laisser voir le héros.

uniform vec4 stone_color : source_color = vec4(0.23, 0.22, 0.25, 1.0);
uniform vec4 mortar_color : source_color = vec4(0.07, 0.065, 0.075, 1.0);
uniform vec4 moss_color : source_color = vec4(0.16, 0.22, 0.12, 1.0);
uniform float brick_height = 0.42;
uniform float brick_length = 0.9;
uniform float moss_amount = 0.25;
uniform vec3 hero_pos = vec3(0.0, -1000.0, 0.0);
uniform float cut_radius = 3.4;
uniform float cut_min_height = 0.7;
// Direction horizontale vers la caméra isométrique.
uniform vec2 camera_dir = vec2(0.70710678, 0.70710678);

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Découpe près du héros.
	vec3 to_frag = world_pos - hero_pos;
	float along = dot(to_frag.xz, camera_dir);
	vec2 perp = to_frag.xz - camera_dir * along;
	if (along > -0.4 && along < 9.0 && length(perp) < cut_radius && world_pos.y > cut_min_height) {
		float dither = hash(floor(FRAGCOORD.xy));
		float edge = smoothstep(cut_radius, cut_radius * 0.6, length(perp));
		if (dither < edge * 0.85) {
			discard;
		}
	}

	// Motif de briques : coordonnée horizontale selon la face du mur.
	float u = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
	float v = world_pos.y;
	if (abs(world_normal.y) > 0.5) {
		u = world_pos.x;
		v = world_pos.z;
	}
	float row = floor(v / brick_height);
	float uu = u / brick_length + mod(row, 2.0) * 0.5;
	vec2 cell = vec2(floor(uu), row);
	vec2 f = vec2(fract(uu), fract(v / brick_height));
	float mortar = step(0.06, f.x) * step(f.x, 0.96) * step(0.08, f.y) * step(f.y, 0.94);
	float variation = hash(cell) * 0.35 + 0.8;
	vec3 col = stone_color.rgb * variation;
	float moss = smoothstep(1.0 - moss_amount, 1.0, hash(cell * 1.7 + 3.1)) * smoothstep(1.2, 0.0, v);
	col = mix(col, moss_color.rgb, moss * 0.7);
	col = mix(mortar_color.rgb, col, mortar);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
