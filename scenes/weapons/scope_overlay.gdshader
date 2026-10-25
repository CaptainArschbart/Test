shader_type canvas_item;
// Zielfernrohr: schwarz außerhalb des Kreises, grüner Rand, Fadenkreuz mit Lücke in der Mitte.

uniform float radius = 0.44;      // Anteil der Bildhöhe
uniform float line_width = 0.0016;
uniform vec4 reticle_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform vec4 rim_color : source_color = vec4(0.3, 1.0, 0.45, 1.0);

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = SCREEN_UV - vec2(0.5);
	p.x *= aspect;
	float d = length(p);
	float edge = fwidth(d) * 1.5;
	float outside = smoothstep(radius - edge, radius + edge, d);
	float rim = smoothstep(radius - 0.006 - edge, radius - 0.006, d) * (1.0 - outside);
	// Fadenkreuz: dünne Linien, innen eine kleine Lücke, außen dicker.
	float thick = line_width * (d > radius * 0.55 ? 3.0 : 1.0);
	float cross = (abs(p.x) < thick || abs(p.y) < thick) && d > 0.012 ? 1.0 : 0.0;
	// Leichte Vignette am Rand der Linse.
	float vignette = smoothstep(radius * 0.6, radius, d) * 0.55;
	vec4 col = vec4(0.0, 0.0, 0.0, vignette);
	col = mix(col, reticle_color, cross * (1.0 - outside));
	col = mix(col, rim_color, rim);
	col = mix(col, vec4(0.0, 0.0, 0.0, 1.0), outside);
	COLOR = col;
}
