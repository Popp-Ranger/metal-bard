shader_type canvas_item;
// Post-traitement « Darkest Dungeon » : contours encrés, désaturation,
// teinte sépia froide, vignette lourde et grain de pellicule.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float ink_strength = 0.45;
uniform float ink_threshold = 0.08;
uniform float desaturation = 0.2;
uniform vec3 tint = vec3(1.0, 0.92, 0.84);
uniform float vignette = 0.4;
uniform float grain = 0.035;
uniform float contrast = 1.08;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * 1.5;
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;

	// Contours : filtre de Sobel sur la luminance.
	float tl = luma(textureLod(screen_tex, SCREEN_UV + vec2(-px.x, -px.y), 0.0).rgb);
	float t = luma(textureLod(screen_tex, SCREEN_UV + vec2(0.0, -px.y), 0.0).rgb);
	float tr = luma(textureLod(screen_tex, SCREEN_UV + vec2(px.x, -px.y), 0.0).rgb);
	float l = luma(textureLod(screen_tex, SCREEN_UV + vec2(-px.x, 0.0), 0.0).rgb);
	float r = luma(textureLod(screen_tex, SCREEN_UV + vec2(px.x, 0.0), 0.0).rgb);
	float bl = luma(textureLod(screen_tex, SCREEN_UV + vec2(-px.x, px.y), 0.0).rgb);
	float b = luma(textureLod(screen_tex, SCREEN_UV + vec2(0.0, px.y), 0.0).rgb);
	float br = luma(textureLod(screen_tex, SCREEN_UV + vec2(px.x, px.y), 0.0).rgb);
	float gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
	float gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
	float edge = smoothstep(ink_threshold, ink_threshold * 3.0, sqrt(gx * gx + gy * gy));
	c *= 1.0 - edge * ink_strength;

	// Désaturation + teinte + contraste.
	float y = luma(c);
	c = mix(c, vec3(y), desaturation) * tint;
	c = (c - 0.5) * contrast + 0.5;

	// Vignette.
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.3, 1.0);
	float v = smoothstep(0.95, 0.3, length(d));
	c *= mix(1.0 - vignette, 1.0, v);

	// Grain.
	float n = fract(sin(dot(SCREEN_UV * (TIME + 1.0), vec2(12.9898, 78.233))) * 43758.5453);
	c += (n - 0.5) * grain;

	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
