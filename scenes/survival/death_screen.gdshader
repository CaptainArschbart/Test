shader_type canvas_item;
// Death-Screen: Bild wird rot-monochrom, dunkel, verrauscht, mit Scanlines und Zeilen-Glitch
// (wie ein abreißender Kamera-Feed). Liest den ganzen Bildschirm inkl. HUD.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// 0 = aus, 1 = voll tot.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float time_s = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.16, 0.28);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// Einzelne Zeilenbänder springen kurz zur Seite.
	float band = floor(uv.y * 48.0);
	float tick = floor(time_s * 14.0);
	float g = step(0.965, hash(band + tick * 7.13));
	uv.x += (hash(band * 3.1 + tick) - 0.5) * 0.05 * g * amount;

	vec3 col = textureLod(screen_tex, uv, amount * 1.5).rgb;
	float gray = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 mono = vec3(gray) * tint * 1.4;
	col = mix(col, mono, smoothstep(0.0, 0.7, amount));

	// Dunkler werden, Vignette.
	vec2 p = SCREEN_UV - 0.5;
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float v = smoothstep(0.25, 0.85, length(p));
	col *= 1.0 - amount * (0.45 + 0.45 * v);

	// Scanlines und Rauschen.
	float scan = 0.5 + 0.5 * sin(FRAGCOORD.y * 3.14159);
	col *= 1.0 - amount * 0.18 * scan;
	vec2 cell = floor(FRAGCOORD.xy * 0.5) + vec2(fract(time_s * 7.0) * 97.0);
	float grain = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	col += grain * 0.07 * amount;

	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
