shader_type spatial;
render_mode cull_disabled;

// Hand-forged plate: mottled patina, roughness variation and a faint
// hammered bump, all procedural (no textures) so it stays tiny for the web.

uniform vec4 albedo : source_color = vec4(0.8, 0.82, 0.85, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.85;
uniform float roughness : hint_range(0.0, 1.0) = 0.32;
uniform float patina : hint_range(0.0, 1.0) = 0.45;
uniform float hammer : hint_range(0.0, 3.0) = 1.0;

varying vec3 wpos;

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
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float m = fbm(wpos * 16.0);
	float grime = smoothstep(0.55, 0.78, fbm(wpos * 6.0 + vec3(3.1, 1.7, 5.3)));
	float fine = noise(wpos * 160.0);

	vec3 col = albedo.rgb * mix(1.0, 0.78 + 0.44 * m, patina);
	col *= 1.0 - patina * 0.3 * grime;
	ALBEDO = col;
	METALLIC = metallic;
	ROUGHNESS = clamp(roughness + patina * ((m - 0.5) * 0.35 + grime * 0.15) + (fine - 0.5) * 0.06, 0.04, 1.0);

	// Hammer marks: bump from noise derivatives (no tangents needed).
	float fade = smoothstep(4.5, 1.2, length(VERTEX));
	float h = fbm(wpos * 30.0) * 0.0007 * hammer * fade;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhx = dFdx(h);
	float dhy = dFdy(h);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	vec3 bumped = abs(det) * NORMAL - grad;
	if (dot(bumped, bumped) > 1e-20) {
		NORMAL = normalize(bumped);
	}
}
