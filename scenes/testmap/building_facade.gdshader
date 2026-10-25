shader_type spatial;
// Hausfassade ohne Textur: Fensterraster in Weltkoordinaten, ein Teil der Fenster leuchtet.
// Funktioniert auf beliebig großen CSG-Boxen, ohne UVs anzupassen.

uniform vec3 wall_color : source_color = vec3(0.05, 0.05, 0.08);
uniform vec3 glass_color : source_color = vec3(0.015, 0.02, 0.035);
// Breite und Höhe einer Fensterzelle in Metern.
uniform vec2 cell_size = vec2(2.5, 3.2);
// Anteil beleuchteter Fenster (0 = alle dunkel, 1 = alle an).
uniform float lit_ratio : hint_range(0.0, 1.0) = 0.35;
uniform float emission_strength = 2.5;
// Unterhalb dieser Höhe keine Fenster (Erdgeschoss).
uniform float first_floor_height = 3.0;
uniform vec3 color_warm : source_color = vec3(1.0, 0.72, 0.4);
uniform vec3 color_cyan : source_color = vec3(0.0, 0.85, 1.0);
uniform vec3 color_magenta : source_color = vec3(1.0, 0.2, 0.85);

varying vec3 world_pos;
varying vec3 world_normal;

// Hash ohne sin(), damit es auf allen GPUs gleich und ohne Rauschen aussieht.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	ALBEDO = wall_color;
	ROUGHNESS = 0.85;
	METALLIC = 0.1;
	// Nur senkrechte Flächen bekommen Fenster, Dächer bleiben glatt.
	if (abs(world_normal.y) < 0.5) {
		float u = abs(world_normal.x) > abs(world_normal.z) ? world_pos.z : world_pos.x;
		vec2 p = vec2(u, world_pos.y - first_floor_height) / cell_size;
		vec2 cell = floor(p);
		vec2 f = fract(p);
		float window = step(0.18, f.x) * step(f.x, 0.82) * step(0.28, f.y) * step(f.y, 0.78);
		window *= step(first_floor_height, world_pos.y);
		vec2 seed = cell + round(world_normal.xz) * 37.0;
		float lit = step(1.0 - lit_ratio, hash(seed));
		float pick = hash(seed * 1.37 + 3.1);
		vec3 col = pick < 0.6 ? color_warm : (pick < 0.8 ? color_cyan : color_magenta);
		ALBEDO = mix(wall_color, glass_color, window);
		ROUGHNESS = mix(0.85, 0.12, window);
		EMISSION = col * window * lit * emission_strength * (0.55 + 0.45 * hash(seed + 9.0));
	}
}
