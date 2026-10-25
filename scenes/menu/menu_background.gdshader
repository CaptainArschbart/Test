shader_type canvas_item;
// Hintergrund des Hauptmenüs: Nachthimmel mit Sternen, Mond, Wolken und
// Flugtaxis, drei Häuserreihen mit Fenstern und Leuchtreklamen, darunter nasser
// Boden mit Spiegelung. Links abgedunkelt, damit Titel und Knöpfe lesbar sind.

uniform vec4 sky_top : source_color = vec4(0.01, 0.0, 0.035, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.26, 0.03, 0.28, 1.0);
uniform vec4 haze_color : source_color = vec4(0.55, 0.12, 0.48, 1.0);
uniform vec4 neon_magenta : source_color = vec4(1.0, 0.15, 0.7, 1.0);
uniform vec4 neon_cyan : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform vec4 window_warm : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform float horizon = 0.7;
// Wie schnell die Stadt seitlich vorbeizieht.
uniform float drift_speed = 0.0035;
// Helligkeit am linken Rand (1 = keine Abdunklung).
uniform float left_shade = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

vec3 sky(vec2 uv, float aspect, float t) {
	float g = clamp(uv.y / horizon, 0.0, 1.0);
	vec3 col = mix(sky_top.rgb, sky_horizon.rgb, pow(g, 1.8));

	// Sterne, nur im oberen Teil
	vec2 sp = vec2(uv.x * aspect, uv.y) * 140.0;
	vec2 si = floor(sp);
	float star = step(0.986, hash(si));
	float twinkle = 0.5 + 0.5 * sin(t * 1.7 + hash(si + 1.0) * 6.28);
	float sd = length(fract(sp) - 0.5);
	col += vec3(0.8, 0.85, 1.0) * star * smoothstep(0.2, 0.0, sd) * twinkle * (1.0 - g) * 0.8;

	// Mond mit Halo
	float md = length(vec2(uv.x * aspect, uv.y) - vec2(0.76 * aspect, 0.2));
	vec2 mp = vec2(uv.x * aspect, uv.y) - vec2(0.76 * aspect, 0.2);
	float spots = fbm(mp * 40.0 + 3.0);
	vec3 moon = mix(vec3(1.0, 0.84, 0.96), vec3(0.85, 0.6, 0.85), smoothstep(0.45, 0.75, spots));
	moon *= 0.8 + 0.2 * smoothstep(0.06, -0.02, mp.x + mp.y);  // Licht von oben links
	col = mix(col, moon, smoothstep(0.062, 0.058, md) * 0.9);
	col += neon_magenta.rgb * 0.22 * exp(-md * 8.0);

	// Wolkenbänder, von der Stadt rosa angeleuchtet
	float c = fbm(vec2(uv.x * 2.5 + t * 0.008, uv.y * 6.0));
	float clouds = smoothstep(0.48, 0.82, c) * smoothstep(0.15, 0.7, g);
	col = mix(col, haze_color.rgb * (0.25 + 0.55 * g), clouds * 0.45);

	// Flugtaxis: blinkende Lichtpunkte, die quer über den Himmel ziehen
	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float y = 0.16 + hash(vec2(fi, 1.0)) * 0.34;
		float speed = 0.01 + hash(vec2(fi, 2.0)) * 0.025;
		float dir = hash(vec2(fi, 3.0)) > 0.5 ? 1.0 : -1.0;
		float x = fract(hash(vec2(fi, 4.0)) + t * speed * dir);
		float d = length(vec2((uv.x - x) * aspect, uv.y - y));
		vec3 lc = hash(vec2(fi, 5.0)) > 0.5 ? neon_cyan.rgb : vec3(1.0, 0.35, 0.3);
		float blink = 0.55 + 0.45 * step(0.5, fract(t * 1.3 + fi * 0.37));
		col += lc * smoothstep(0.0035, 0.0, d) * blink;
		col += lc * 0.15 * exp(-d * 260.0) * blink;
	}
	return col;
}

// Eine Häuserreihe (0 = hinten, 2 = vorne). rgb = Farbe, a = Deckung.
vec4 buildings(vec2 uv, float layer, float t) {
	float cols = 30.0 - layer * 8.0;
	float x = uv.x * cols + t * drift_speed * cols * (0.4 + layer * 0.5) + layer * 13.7;
	float id = floor(x);
	float fx = fract(x);
	float h = mix(0.06, 0.16 + layer * 0.12, hash(vec2(id, layer * 7.1)));
	// Aufbau auf manchen Dächern
	if (hash(vec2(id, layer + 3.3)) > 0.55 && fx > 0.3 && fx < 0.72) {
		h += 0.03 + 0.03 * layer;
	}
	// Antenne mit rotem Blinklicht
	bool antenna = hash(vec2(id, layer + 9.1)) > 0.8;
	if (antenna && abs(fx - 0.5) < 0.025) {
		h += 0.06;
	}
	float top = horizon - h;
	if (uv.y < top || fx < 0.03 || fx > 0.97) {
		if (antenna && abs(fx - 0.5) < 0.12 && abs(uv.y - (top - 0.004)) < 0.006) {
			float on = step(0.5, fract(t * 0.8 + id * 0.13));
			return vec4(vec3(1.0, 0.1, 0.1) * on, on * smoothstep(0.12, 0.0, abs(fx - 0.5)));
		}
		return vec4(0.0);
	}

	float far = 1.0 - layer / 2.0;
	vec3 col = mix(vec3(0.015, 0.0, 0.04), haze_color.rgb * 0.22, far);

	// Fenster
	vec2 cell = vec2(fx * (7.0 - layer), (uv.y - top) * (150.0 - layer * 35.0));
	vec2 wid = floor(cell);
	vec2 wf = fract(cell);
	float win = step(0.22, wf.x) * step(wf.x, 0.78) * step(0.28, wf.y) * step(wf.y, 0.72);
	float lit = step(0.76, hash(wid + vec2(id * 17.0, layer * 31.0)));
	float tint = hash(wid + vec2(id, 5.0));
	vec3 wc = tint < 0.7 ? window_warm.rgb : (tint < 0.85 ? neon_cyan.rgb : neon_magenta.rgb);
	col += wc * win * lit * mix(0.6, 0.22, far);

	// Senkrechte Leuchtreklame
	if (hash(vec2(id, layer + 21.7)) > 0.7) {
		float y0 = top + 0.015;
		float y1 = y0 + 0.08 + 0.07 * layer;
		float sx = abs(fx - 0.2);
		if (uv.y > y0 && uv.y < y1 && sx < 0.07) {
			vec3 nc = hash(vec2(id, 2.0)) > 0.5 ? neon_magenta.rgb : neon_cyan.rgb;
			float on = step(0.06, hash(vec2(id, floor(t * 2.5))));
			float rim = smoothstep(0.07, 0.05, sx);
			col = mix(col, nc * 1.2, rim * on * mix(0.9, 0.5, far));
		}
	}

	// Dachkante leicht angeleuchtet
	col += haze_color.rgb * 0.25 * smoothstep(0.004, 0.0, uv.y - top) * (1.0 - far);

	// Dunst nach hinten
	col = mix(col, haze_color.rgb * 0.38, far * 0.45);
	return vec4(col, 1.0);
}

vec3 city(vec2 uv, float aspect, float t) {
	vec3 col = sky(uv, aspect, t);
	col += haze_color.rgb * exp(-(horizon - uv.y) * 10.0) * 0.4;
	for (int l = 0; l < 3; l++) {
		vec4 b = buildings(uv, float(l), t);
		col = mix(col, b.rgb, b.a);
	}
	// Bodennebel zwischen den Häusern
	col += haze_color.rgb * exp(-(horizon - uv.y) * 40.0) * 0.25;
	return col;
}

void fragment() {
	vec2 uv = UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float t = TIME;
	vec3 col;

	if (uv.y < horizon) {
		col = city(uv, aspect, t);
	} else {
		// Nasser Boden: gestauchte, gewellte Spiegelung der Stadt
		float d = uv.y - horizon;
		float wave = sin(d * 170.0 - t * 1.8) * 0.0025 + (noise(vec2(uv.x * 50.0, d * 260.0 - t * 1.5)) - 0.5) * 0.006;
		vec2 ruv = vec2(uv.x + wave * smoothstep(0.0, 0.05, d), horizon - d * 1.4);
		vec3 refl = city(ruv, aspect, t);
		col = mix(vec3(0.008, 0.0, 0.025), refl, 0.38 * exp(-d * 2.5));

		// Dezentes Gitter in der Pfütze
		float z = 0.06 / max(d, 0.001);
		float gx = (uv.x - 0.5) * z * 5.0;
		float gz = z + t * 0.2;
		float lx = abs(fract(gx) - 0.5);
		float lz = abs(fract(gz) - 0.5);
		float line = max(1.0 - smoothstep(0.0, fwidth(gx) * 1.2, lx), 1.0 - smoothstep(0.0, fwidth(gz) * 1.2, lz));
		col += neon_magenta.rgb * line * 0.12 * smoothstep(0.0, 0.25, d);
		col += haze_color.rgb * exp(-d * 30.0) * 0.45;
	}

	col *= mix(left_shade, 1.0, smoothstep(0.05, 0.62, uv.x));
	COLOR = vec4(col, 1.0);
}
