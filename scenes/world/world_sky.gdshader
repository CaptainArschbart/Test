shader_type sky;
// Himmel für den Tag-Nacht-Zyklus (WorldAtmosphere setzt alle Uniforms).
// Farbverlauf, Sonne, Mond, Sterne, Wolken und der Lichtschein der Stadt am Horizont.
// Im Cubemap-Pass (Reflexionen, Umgebungslicht) ohne Sterne und mit einfachen Wolken.

uniform vec3 zenith_color : source_color = vec3(0.02, 0.025, 0.06);
uniform vec3 horizon_color : source_color = vec3(0.09, 0.07, 0.13);
uniform vec3 ground_color : source_color = vec3(0.02, 0.02, 0.03);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float sun_strength = 1.0;
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float moon_strength = 0.0;
uniform float star_strength = 0.0;
// Lichtverschmutzung der Stadt: färbt den Horizont und die Wolken von unten.
uniform vec3 city_glow : source_color = vec3(0.42, 0.13, 0.36);
uniform float city_strength = 0.0;
uniform float cloud_cover = 0.3;
uniform vec3 cloud_color : source_color = vec3(0.8, 0.8, 0.85);
uniform vec3 cloud_shade : source_color = vec3(0.3, 0.3, 0.38);
uniform vec2 cloud_offset = vec2(0.0);

// Ganzzahl-Hash für Gitterzellen (p = floor-Werte). Ein fract()-Hash ist bei großen Werten so
// empfindlich, dass Rundungsunterschiede der GPU Nachbarzellen verschieden machen: harte Kanten.
float hash2(vec2 p) {
	uvec2 q = uvec2(ivec2(p) + ivec2(100000));
	uint h = q.x * 1597334677u ^ q.y * 3812015801u;
	h ^= h >> 16u;
	h *= 2146121005u;
	h ^= h >> 15u;
	h *= 2221713035u;
	h ^= h >> 16u;
	return float(h) * (1.0 / 4294967295.0);
}

float hash3(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

vec2 grad(vec2 i) {
	float a = hash2(i) * 6.2831853;
	return vec2(cos(a), sin(a));
}

// Gradientenrauschen (0..1) mit quintischer Kurve. Wertrauschen zeigt sein Gitter, das auf der
// Wolkenebene in der Perspektive wie riesige Kästen am Himmel aussieht.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(grad(i), f);
	float b = dot(grad(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(grad(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(grad(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.75 + 0.5;
}

float fbm(vec2 p, int octaves) {
	// Jede Oktave gedreht, damit sich keine Gitterlinien aufaddieren.
	const mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < octaves; i++) {
		v += amp * noise(p);
		p = rot * p * 2.03 + vec2(17.1, 9.7);
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;
	float h = max(up, 0.0);

	// Grundverlauf: Horizont -> Zenit, unter dem Horizont dunkler Boden.
	vec3 col = mix(horizon_color, zenith_color, pow(h, 0.45));
	col = mix(col, ground_color, smoothstep(0.0, -0.12, up));

	// Sonne: Scheibe, Hof und warmes Leuchten am Horizont in ihrer Richtung.
	float sd = max(dot(dir, sun_dir), 0.0);
	float sun_low = 1.0 - smoothstep(0.0, 0.35, sun_dir.y);
	col += sun_color * sun_strength * (pow(sd, 8.0) * 0.25 + pow(sd, 64.0) * 0.4) * (0.4 + sun_low);
	col += sun_color * sun_strength * sun_low * pow(sd, 3.0) * exp(-h * 6.0) * 0.6;

	// Lichtschein der Stadt am Horizont (nachts).
	col += city_glow * city_strength * exp(-h * 7.0) * smoothstep(-0.1, 0.02, up);

	// Sterne, nicht im Cubemap-Pass (würden in Reflexionen nur rauschen).
	if (!AT_CUBEMAP_PASS && star_strength > 0.001 && up > 0.0) {
		vec3 cell = floor(dir * 260.0);
		float s = hash3(cell);
		float star = smoothstep(0.9965, 1.0, s);
		float twinkle = 0.7 + 0.3 * sin(TIME * (2.0 + s * 5.0) + s * 40.0);
		col += vec3(0.85, 0.9, 1.0) * star * twinkle * star_strength * smoothstep(0.05, 0.35, up);
	}

	// Mond: Scheibe mit leichten Flecken und kühlem Hof.
	float md = dot(dir, moon_dir);
	if (moon_strength > 0.001 && md > 0.9) {
		float disc = smoothstep(0.99935, 0.9996, md);
		vec3 local = dir - moon_dir;
		float spots = 0.8 + 0.2 * noise(local.xz * 900.0 + local.y * 300.0);
		col += vec3(0.9, 0.93, 1.0) * disc * spots * moon_strength * 1.6;
		col += vec3(0.35, 0.42, 0.65) * pow(max(md, 0.0), 300.0) * moon_strength * 0.5;
	}

	// Wolken auf einer gedachten Ebene über der Stadt.
	if (up > 0.0 && cloud_cover > 0.01) {
		vec2 uv = dir.xz / (up + 0.12) * 1.6 + cloud_offset;
		float n = AT_CUBEMAP_PASS ? fbm(uv, 3) : fbm(uv, 5);
		float threshold = 1.0 - cloud_cover;
		float density = smoothstep(threshold - 0.08, threshold + 0.35, n);
		// Unterseite dunkler, zur Sonne hin heller.
		float lit = clamp(0.35 + (n - threshold) * 1.4, 0.0, 1.0);
		vec3 c = mix(cloud_shade, cloud_color, lit);
		c += sun_color * sun_strength * pow(sd, 6.0) * 0.5 * (1.0 - density * 0.5);
		c += city_glow * city_strength * 0.35;
		c += vec3(0.5, 0.55, 0.7) * moon_strength * pow(max(md, 0.0), 12.0) * 0.25;
		float fade = smoothstep(0.0, 0.18, up);
		col = mix(col, c, density * fade);
	}

	COLOR = col;
}
