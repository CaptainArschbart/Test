shader_type spatial;
// Fassade für große Hintergrund-Gebäude im Slum: Wandtextur in Weltkoordinaten (keine UVs nötig),
// Fensterraster mit Rahmen, Sims und Licht hinter einem Teil der Fenster, Schmutzläufer darüber.
// Billiger als echte Fenster-Quads, deshalb für die Hochhäuser am Rand.

uniform sampler2D wall_tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D grime_tex : filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tile_meters = 3.0;
// Breite und Höhe einer Fensterzelle in Metern.
uniform vec2 cell_size = vec2(2.6, 3.0);
uniform float lit_ratio : hint_range(0.0, 1.0) = 0.3;
uniform float emission_strength = 2.2;
uniform float first_floor_height = 3.0;
uniform float seed_offset = 0.0;
uniform vec3 color_warm : source_color = vec3(1.0, 0.68, 0.38);
uniform vec3 color_cool : source_color = vec3(0.55, 0.8, 1.0);
uniform vec3 color_pink : source_color = vec3(1.0, 0.35, 0.65);

varying vec3 world_pos;
varying vec3 world_normal;

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
	bool wall = abs(world_normal.y) < 0.5;
	float u = abs(world_normal.x) > abs(world_normal.z) ? world_pos.z : world_pos.x;
	vec2 wuv = wall ? vec2(u, -world_pos.y) : world_pos.xz;
	vec3 base = texture(wall_tex, wuv / tile_meters).rgb * tint.rgb;
	float grime = texture(grime_tex, vec2(u * 0.07, -world_pos.y * 0.035)).r;
	base *= mix(0.55, 1.0, grime);
	ALBEDO = base;
	ROUGHNESS = 0.9;
	if (wall) {
		vec2 p = vec2(u, world_pos.y - first_floor_height) / cell_size;
		vec2 cell = floor(p);
		vec2 f = fract(p);
		float frame = step(0.16, f.x) * step(f.x, 0.84) * step(0.22, f.y) * step(f.y, 0.8);
		float glass = step(0.2, f.x) * step(f.x, 0.8) * step(0.26, f.y) * step(f.y, 0.76);
		float mullion = 1.0 - step(0.485, f.x) * step(f.x, 0.515);
		float above_ground = step(first_floor_height, world_pos.y);
		vec2 seed = cell + round(world_normal.xz) * 37.0 + seed_offset;
		// Manche Zellen sind zugemauert
		float exists = step(0.08, hash(seed * 0.73 + 1.7)) * above_ground;
		frame *= exists;
		glass *= exists * mullion;
		float sill = step(0.17, f.y) * step(f.y, 0.22) * step(0.12, f.x) * step(f.x, 0.88) * exists;
		float lit = step(1.0 - lit_ratio, hash(seed));
		float pick = hash(seed * 1.37 + 3.1);
		vec3 col = pick < 0.65 ? color_warm : (pick < 0.85 ? color_cool : color_pink);
		// Vorhang: oberer Teil dunkler
		float curtain = step(0.5, hash(seed + 5.0)) * step(0.62, f.y);
		vec3 glass_col = mix(vec3(0.02, 0.025, 0.035), col * 0.35, lit);
		ALBEDO = mix(ALBEDO, vec3(0.06, 0.065, 0.07), frame - glass);
		ALBEDO = mix(ALBEDO, glass_col, glass);
		ALBEDO = mix(ALBEDO, vec3(0.32, 0.32, 0.3) * base * 2.0, sill);
		ROUGHNESS = mix(ROUGHNESS, 0.15, glass);
		float flicker = 0.6 + 0.4 * hash(seed + 9.0);
		EMISSION = col * glass * lit * emission_strength * flicker * (1.0 - curtain * 0.6);
		// Schmutzläufer unter den Fenstern
		float drip = (1.0 - step(0.22, f.y)) * step(0.3, f.x) * step(f.x, 0.7) * exists;
		ALBEDO *= 1.0 - drip * 0.25 * (1.0 - f.y * 4.0);
	}
}
