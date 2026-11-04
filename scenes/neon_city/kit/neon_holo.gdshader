shader_type spatial;
// Holo-Werbung der Neon City (Schedule 1, P1-1): legt sich über ein vorhandenes Modell aus den
// Packs (Leuchtschild, Werbetafel). Durchscheinend (nicht additiv: das Schild hat viele
// übereinanderliegende Schichten, die sonst zu Weiß aufaddieren), waagerechte Scanlines, ein
// wandernder heller Streifen, leichtes Flackern pro Exemplar und ein leuchtender Rand (Fresnel).
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform float energy = 2.4;
// Linien pro Meter (Weltkoordinaten, bleibt bei jeder Skalierung gleich fein).
uniform float scan_density = 9.0;
// Deckkraft dieser Fläche: 1 = Schrift und Rahmen, klein = Grundplatte (nur ein Schimmer).
uniform float strength = 1.0;

varying vec3 world_pos;
varying float seed;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Jedes Exemplar flackert anders (MultiMesh: Lage des Exemplars als Startwert).
	seed = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float t = TIME + seed * 10.0;
	float scan = 0.55 + 0.45 * sin(world_pos.y * scan_density * 6.2832 - t * 4.0);
	float sweep = smoothstep(0.92, 1.0, fract(world_pos.y * 0.08 - t * 0.25));
	float flicker = 0.88 + 0.12 * sin(t * 31.0) * sin(t * 7.3);
	// Gelegentlicher Aussetzer (Glitch), etwa alle paar Sekunden für Sekundenbruchteile.
	float glitch = step(0.985, fract(sin(floor(t * 8.0) * 91.7 + seed) * 1000.0));
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	float body = (0.3 + 0.6 * scan) * flicker * (1.0 - glitch * 0.8);
	// Farbe knapp über 1 (leichter Glow), Deckkraft begrenzt: bleibt farbig und durchscheinend.
	ALBEDO = tint.rgb * energy * (1.0 + sweep * 0.5);
	ALPHA = clamp((body + rim * 0.4 + sweep * 0.3) * strength, 0.0, 0.95);
}
