shader_type canvas_item;
// Aura rouge sur le pourtour de l'écran (vie basse) : transparente au centre, rouge vers les bords.
// `intensity` (0..1) est animée par le HUD pour la faire clignoter.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(0.85, 0.02, 0.02, 1.0);

void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0; // 0 au centre, 1 sur les bords
	float edge = max(pow(d.x, 6.0), pow(d.y, 4.0));
	edge = max(edge, smoothstep(0.55, 1.35, length(d)));
	COLOR = vec4(color.rgb, clamp(edge, 0.0, 1.0) * intensity * 0.85);
}
