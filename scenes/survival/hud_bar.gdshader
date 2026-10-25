shader_type canvas_item;

uniform float segments = 8.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float count = max(segments, 1.0);
	float gap = step(0.84, fract(UV.x * count));
	float sheen = 1.0 - smoothstep(0.0, 0.28, UV.y);
	base.rgb += base.rgb * sheen * 0.55;
	base.rgb = mix(base.rgb, vec3(0.02, 0.0, 0.05), gap * base.a);
	COLOR = base;
}
