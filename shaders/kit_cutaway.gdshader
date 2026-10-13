shader_type spatial;
// Pièces texturées des kits (Modular Dungeon Kit de Kenney : murs, coins, piliers, arches) avec la découpe
// « façon Diablo » de stone_wall.gdshader : ce qui se trouve entre la caméra et le héros est tramé pour le laisser voir.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec3 hero_pos = vec3(0.0, -1000.0, 0.0);
uniform float cut_radius = 3.6;
uniform float cut_min_height = 0.8;
// Direction horizontale vers la caméra isométrique.
uniform vec2 camera_dir = vec2(0.70710678, 0.70710678);

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 to_frag = world_pos - hero_pos;
	float along = dot(to_frag.xz, camera_dir);
	vec2 perp = to_frag.xz - camera_dir * along;
	if (along > -0.4 && along < 11.0 && length(perp) < cut_radius && world_pos.y > cut_min_height) {
		float dither = hash(floor(FRAGCOORD.xy));
		float edge = smoothstep(cut_radius, cut_radius * 0.6, length(perp));
		if (dither < edge * 0.9) {
			discard;
		}
	}
	ALBEDO = texture(albedo_tex, UV).rgb * tint.rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
}
