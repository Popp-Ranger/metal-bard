shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;
// Disque de portail : spirale violette animée.

uniform vec4 color_a : source_color = vec4(0.55, 0.25, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.15, 0.8, 1.0, 1.0);
uniform float intensity = 0.55;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float spiral = sin(a * 4.0 + r * 14.0 - TIME * 5.0) * 0.5 + 0.5;
	float ring = smoothstep(1.0, 0.85, r) * smoothstep(0.0, 0.5, r);
	vec3 col = mix(color_a.rgb, color_b.rgb, spiral * (1.0 - r));
	float core = smoothstep(0.5, 0.0, r) * 0.25;
	ALBEDO = col * (ring * (0.4 + spiral * 0.8) + core) * intensity;
	ALPHA = 1.0;
}
