shader_type canvas_item;
// Liquide d'un réservoir du HUD (le cœur de la main : la vie ; la cuve de l'enceinte : les décibels).
// TEXTURE = masque du réservoir (blanc là où se voit le liquide, transparent ailleurs, assets/ui/*_masque.png).
// Le niveau monte de `bottom` (fill = 0) à `top` (fill = 1), en coordonnées UV verticales de l'image.

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float top = 0.0;
uniform float bottom = 1.0;
uniform vec4 deep_color : source_color = vec4(0.35, 0.0, 0.02, 1.0);
uniform vec4 bright_color : source_color = vec4(1.0, 0.15, 0.08, 1.0);
uniform vec4 foam_color : source_color = vec4(1.0, 0.65, 0.45, 1.0);
// Lueur blanche quand on vient de prendre des dégâts (0 à 1).
uniform float flash = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	float m = texture(TEXTURE, UV).a * texture(TEXTURE, UV).r;
	float level = mix(bottom, top, fill);
	// Surface qui ondule.
	level += sin(UV.x * 38.0 + TIME * 3.0) * 0.004 + sin(UV.x * 17.0 - TIME * 2.1) * 0.004;
	float below = smoothstep(level - 0.004, level + 0.004, UV.y);
	// Liquide : plus sombre au fond, remous qui dérivent, bulles qui montent.
	float depth = clamp((UV.y - level) / max(bottom - top, 0.01), 0.0, 1.0);
	vec3 col = mix(bright_color.rgb, deep_color.rgb, depth * 0.85);
	float swirl = noise(vec2(UV.x * 9.0 + TIME * 0.4, UV.y * 9.0 - TIME * 0.6));
	col *= 0.8 + swirl * 0.45;
	float bubbles = step(0.93, noise(vec2(UV.x * 60.0, UV.y * 30.0 + TIME * 4.0)));
	col = mix(col, foam_color.rgb, bubbles * 0.6);
	// Écume brillante sur la surface.
	float foam = 1.0 - smoothstep(0.0, 0.02, abs(UV.y - level));
	col = mix(col, foam_color.rgb, foam * 0.8);
	col = mix(col, vec3(1.0), flash * 0.6);
	// Au-dessus du niveau : un reflet de verre à peine visible.
	float glass = (1.0 - below) * 0.12 * (1.0 - smoothstep(0.0, 0.3, abs(UV.x - 0.42)));
	float a = m * below;
	float g = m * glass;
	COLOR = vec4(mix(vec3(1.0), col, a / max(a + g, 0.0001)), clamp(a + g, 0.0, 1.0));
}
