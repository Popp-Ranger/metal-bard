shader_type spatial;
// Cœur de la boule de feu (Fireball) : la texture de Voronoi d'Ulysse (assets/textures/feu/voronoi.png) défile en deux
// couches à des vitesses différentes : des cellules de feu qui bouillonnent, plus chaudes au centre (face caméra) et qui
// s'estompent sur le pourtour. Mélange additif : ça brille.
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 hot : source_color = vec4(1.0, 0.88, 0.45, 1.0);
uniform vec4 warm : source_color = vec4(1.0, 0.32, 0.02, 1.0);
uniform float intensity = 0.75;

void fragment() {
	vec2 uv = UV * vec2(2.0, 1.0);
	float a = texture(noise_tex, uv + vec2(TIME * 0.7, TIME * 1.1)).r;
	float b = texture(noise_tex, uv * 1.7 - vec2(TIME * 0.9, TIME * 0.5)).r;
	float n = a * 0.6 + b * 0.4;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 c = mix(warm.rgb, hot.rgb, smoothstep(0.35, 0.95, n));
	ALBEDO = c * intensity * (0.35 + 1.4 * facing * facing);
}
