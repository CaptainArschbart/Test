shader_type canvas_item;
// Liegt über dem ganzen Menü: feine Scanlines, Vignette, leichtes Rauschen und
// seltene, schwache Glitch-Störungen. Keine Farbverschiebung (Chromatic
// Aberration), damit Text scharf bleibt.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.07;
uniform float vignette : hint_range(0.0, 2.0) = 0.7;
uniform float noise_strength : hint_range(0.0, 0.2) = 0.015;
// Wird vom Skript kurzzeitig hochgesetzt (0 = ruhig, 1 = stärkster Glitch).
uniform float glitch : hint_range(0.0, 1.0) = 0.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Beim Glitch verrutschen einzelne horizontale Streifen ein Stück.
	float band = floor(uv.y * 32.0 + floor(TIME * 14.0) * 3.0);
	uv.x += (hash(band) - 0.5) * 0.015 * glitch * step(0.75, hash(band + 1.7));

	vec3 col = texture(screen_tex, uv).rgb;

	// Scanlines (an Bildschirmpixel gebunden), kaum Flackern
	float scan = sin(FRAGCOORD.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * scan;
	col *= 0.99 + 0.01 * sin(TIME * 50.0);

	col += (hash(dot(FRAGCOORD.xy, vec2(12.9898, 78.233)) + TIME) - 0.5) * noise_strength;

	vec2 v = SCREEN_UV - 0.5;
	col *= 1.0 - dot(v, v) * vignette;

	COLOR = vec4(col, 1.0);
}
