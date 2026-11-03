shader_type spatial;

// Carved, varnished wood: growth rings that wander with noise, fine fibre
// streaks along the grain, and a light varnish sheen. Procedural, so the
// mannequin needs no textures. Grain runs along each segment's local Y.

uniform vec4 light_col : source_color = vec4(0.36, 0.22, 0.115, 1.0);
uniform vec4 dark_col : source_color = vec4(0.22, 0.12, 0.055, 1.0);
uniform float ring_freq = 85.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.42;

varying vec3 lp;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.07;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 p = lp;
	float warp = fbm(p * vec3(9.0, 1.2, 9.0));
	float r = length(p.xz + vec2(0.31, 0.17)) * ring_freq + warp * 5.0 + p.y * 2.0;
	float ring = fract(r);
	float late = smoothstep(0.68, 0.84, ring) * smoothstep(1.0, 0.9, ring);
	float fibre = noise(p * vec3(420.0, 9.0, 420.0));
	float blot = fbm(p * 14.0 + 3.7);

	vec3 col = mix(light_col.rgb, dark_col.rgb, late * 0.7);
	col *= 0.9 + 0.16 * fibre;
	col *= 0.92 + 0.16 * blot;
	ALBEDO = col;
	ROUGHNESS = clamp(roughness + late * 0.1 - fibre * 0.06, 0.05, 1.0);
	SPECULAR = 0.45;
}
