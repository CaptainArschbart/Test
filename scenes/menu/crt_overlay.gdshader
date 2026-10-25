shader_type canvas_item;
// Liegt über dem ganzen Menü: Scanlines, Farbverschiebung (Chromatic
// Aberration), Vignette und kurze Glitch-Störungen.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.22;
uniform float aberration : hint_range(0.0, 0.02) = 0.0025;
uniform float vignette : hint_range(0.0, 2.0) = 0.9;
// Wird vom Skript kurzzeitig hochgesetzt (0 = ruhig, 1 = starker Glitch).
uniform float glitch : hint_range(0.0, 1.0) = 0.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Horizontale Streifen, die beim Glitch seitlich verrutschen
	float band = floor(uv.y * 24.0 + floor(TIME * 18.0) * 3.0);
	float shift = (hash(band) - 0.5) * 0.08 * glitch * step(0.6, hash(band + 1.7));
	uv.x += shift;

	float ab = aberration + glitch * 0.012;
	float r = texture(screen_tex, uv + vec2(ab, 0.0)).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - vec2(ab, 0.0)).b;
	vec3 col = vec3(r, g, b);

	// Scanlines (an Bildschirmpixel gebunden) und leichtes Flackern
	float scan = sin(FRAGCOORD.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_strength * scan;
	col *= 0.97 + 0.03 * sin(TIME * 60.0);

	// Rauschen
	col += (hash(dot(FRAGCOORD.xy, vec2(12.9898, 78.233)) + TIME) - 0.5) * 0.04;

	// Vignette
	vec2 v = SCREEN_UV - 0.5;
	col *= 1.0 - dot(v, v) * vignette;

	COLOR = vec4(col, 1.0);
}
