shader_type canvas_item;
// Low-Health: rote Vignette mit Herzschlag-Puls, Entsättigung und Tunnelblick.
// Liest das fertige 3D-Bild (Bildschirm-Textur). Liegt unter dem HUD (CanvasLayer 1),
// die Leisten bleiben also farbig und lesbar.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// 0 = gesund, 1 = fast tot.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
// Hüllkurve des Herzschlags (0…1).
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
// Kurzer Treffer-Blitz (0…1).
uniform float hit : hint_range(0.0, 1.0) = 0.0;
uniform vec3 blood_color : source_color = vec3(0.55, 0.0, 0.05);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 p = uv - 0.5;
	// Kreis statt Ellipse: auf das Seitenverhältnis korrigieren.
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(p);

	// Tunnelblick: Rand wird weicher und leicht verschwommen (Mipmap), Mitte bleibt scharf.
	float inner = mix(0.78, 0.30, intensity) - pulse * 0.05 * intensity;
	float edge = smoothstep(inner, inner + 0.5, r);
	float blur = edge * intensity * 2.5;
	// Leichte Farbtrennung zum Rand hin.
	vec2 shift = normalize(p + 1e-5) * edge * intensity * 0.004;
	vec3 col;
	col.r = textureLod(screen_tex, uv + shift, blur).r;
	col.g = textureLod(screen_tex, uv, blur).g;
	col.b = textureLod(screen_tex, uv - shift, blur).b;

	// Entsättigen, kritisch fast grau.
	float gray = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(gray), intensity * 0.7);

	// Rand abdunkeln und rot einfärben, im Takt pulsierend.
	float vignette = edge * intensity;
	col *= 1.0 - vignette * (0.45 + 0.2 * pulse);
	float red = vignette * (0.35 + 0.5 * pulse) + edge * hit * 0.6 + hit * 0.12;
	col = mix(col, blood_color, clamp(red, 0.0, 0.85));

	COLOR = vec4(col, 1.0);
}
