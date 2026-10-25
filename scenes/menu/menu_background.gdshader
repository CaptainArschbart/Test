shader_type canvas_item;
// Hintergrund des Hauptmenüs: Nachthimmel, Skyline mit Fenstern und ein
// bewegtes Neon-Gitter als Boden.

uniform vec4 sky_top : source_color = vec4(0.02, 0.0, 0.06, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.35, 0.02, 0.32, 1.0);
uniform vec4 grid_color : source_color = vec4(1.0, 0.1, 0.75, 1.0);
uniform vec4 horizon_glow : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform vec4 window_color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform float horizon = 0.62;
uniform float grid_speed = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col;

	if (uv.y < horizon) {
		// Himmel mit Verlauf
		float t = uv.y / horizon;
		col = mix(sky_top.rgb, sky_horizon.rgb, pow(t, 2.2));

		// Skyline: zwei Ebenen Hochhäuser
		for (int layer = 0; layer < 2; layer++) {
			float fl = float(layer);
			float cols = 28.0 + fl * 18.0;
			float bx = floor(uv.x * cols + fl * 7.0);
			float h = 0.12 + hash(vec2(bx, fl)) * (0.32 - fl * 0.12);
			float top = horizon - h;
			if (uv.y > top) {
				vec3 building = mix(vec3(0.03, 0.0, 0.07), vec3(0.08, 0.01, 0.12), fl);
				// Fenster
				vec2 cell = vec2(fract(uv.x * cols + fl * 7.0) * 4.0, (uv.y - top) * 90.0);
				vec2 wid = floor(cell);
				vec2 wf = fract(cell);
				float lit = step(0.72, hash(wid + vec2(bx * 13.0, fl * 5.0)));
				float flicker = step(0.02, hash(wid + floor(TIME * 2.0 + bx)));
				float win = step(0.25, wf.x) * step(wf.x, 0.75) * step(0.3, wf.y) * step(wf.y, 0.7);
				building += window_color.rgb * win * lit * flicker * (0.5 - fl * 0.2);
				col = building;
			}
		}

		// Leuchten am Horizont
		col += horizon_glow.rgb * exp(-(horizon - uv.y) * 28.0) * 0.6;
	} else {
		// Boden mit perspektivischem Gitter
		float d = uv.y - horizon;
		float z = 0.08 / max(d, 0.0005);
		float x = (uv.x - 0.5) * z * 6.0;
		float zz = z + TIME * grid_speed * 4.0;
		float lx = abs(fract(x) - 0.5);
		float lz = abs(fract(zz) - 0.5);
		float w = fwidth(x) * 1.5;
		float wz = fwidth(zz) * 1.5;
		float line = max(1.0 - smoothstep(0.0, w, lx - 0.0), 1.0 - smoothstep(0.0, wz, lz));
		float fade = smoothstep(0.0, 0.25, d);
		col = vec3(0.02, 0.0, 0.05);
		col += grid_color.rgb * line * (0.35 + fade);
		col += horizon_glow.rgb * exp(-d * 30.0) * 0.8;
	}

	COLOR = vec4(col, 1.0);
}
