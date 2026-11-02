shader_type spatial;
render_mode cull_disabled;

// Riveted mail: two staggered ring lattices give the four-in-one interlink.
// UVs are in metres (see mesh_kit.gd), so ring size is constant everywhere.
// Detail fades to an averaged sheen when rings get smaller than a few pixels.

uniform vec4 albedo : source_color = vec4(0.62, 0.63, 0.66, 1.0);
uniform vec4 gap_color : source_color = vec4(0.05, 0.05, 0.055, 1.0);
uniform float ring_size = 0.011;
uniform float metallic : hint_range(0.0, 1.0) = 0.85;

float ring_h(vec2 c) {
	float d = length(c);
	float x = (d - 0.37) / 0.12;
	return max(0.0, 1.0 - x * x);
}

void fragment() {
	vec2 uv = UV / ring_size;
	vec2 c1 = fract(uv) - 0.5;
	vec2 c2 = fract(uv + vec2(0.5, 0.5)) - 0.5;
	c1.y *= 1.15;
	c2.y *= 1.15;
	// Alternate which lattice sits on top per row so rings appear to weave.
	float row = floor(uv.y + 0.5);
	float h1 = ring_h(c1);
	float h2 = ring_h(c2);
	bool top1 = mod(row + floor(uv.x), 2.0) < 1.0;
	float h = top1 ? max(h1, h2 * 0.8) : max(h1 * 0.8, h2);
	vec2 cc = (top1 ? (h1 >= h2 * 0.8) : (h1 * 0.8 > h2)) ? c1 : c2;

	float fw = max(fwidth(uv.x), fwidth(uv.y));
	float detail = 1.0 - smoothstep(0.22, 0.65, fw);
	float mask = smoothstep(0.0, 0.25, h);
	float cover = mix(0.62, mask, detail);

	vec3 col = mix(gap_color.rgb, albedo.rgb * (0.75 + 0.35 * h), cover);
	ALBEDO = col;
	METALLIC = metallic * cover;
	ROUGHNESS = mix(0.85, 0.32, cover);

	// Fake ring relief through the normal map.
	float d = max(length(cc), 1e-4);
	float x = (d - 0.37) / 0.12;
	vec2 slope = (cc / d) * (-2.0 * x) * 0.55 * mask * detail;
	vec3 n = normalize(vec3(-slope, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
