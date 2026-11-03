shader_type spatial;
render_mode cull_disabled;

// Hand-forged plate: mottled patina, roughness variation and a faint
// hammered bump, all procedural (no textures) so it stays tiny for the web.

uniform vec4 albedo : source_color = vec4(0.8, 0.82, 0.85, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.85;
uniform float roughness : hint_range(0.0, 1.0) = 0.32;
uniform float patina : hint_range(0.0, 1.0) = 0.45;
uniform float hammer : hint_range(0.0, 3.0) = 1.0;

// Holes punched through the plate (model space). Each hole is a shape drawn
// on the plane tangent to the surface at its centre and cut straight through
// the shell. w of hole_pos = shape: 0 round, 1 slot, 2 cross.
// hole_size = (width, height) in metres.
const int MAX_HOLES = 64;
uniform int hole_count = 0;
uniform vec4 hole_pos[MAX_HOLES];
uniform vec4 hole_nrm[MAX_HOLES];
uniform vec4 hole_size[MAX_HOLES];
// Hover preview of the next hole (outlined, not cut)
uniform bool preview_on = false;
uniform vec4 preview_pos;
uniform vec4 preview_nrm;
uniform vec4 preview_size;

varying vec3 wpos;
varying vec3 mpos;

float slot_sd(vec2 q, float w, float h) {
	float half_len = max(w * 0.5 - h * 0.5, 0.0);
	return length(vec2(max(abs(q.x) - half_len, 0.0), q.y)) - h * 0.5;
}

// Signed distance (metres, in the hole's plane) from p to the hole edge;
// negative inside. Large when p is not near the hole along its normal.
float hole_sd(vec3 p, vec4 hp, vec4 hn, vec4 hs) {
	vec3 d = p - hp.xyz;
	vec3 n = normalize(hn.xyz);
	if (abs(dot(d, n)) > 0.012) {
		return 1.0;
	}
	vec3 u = cross(vec3(0.0, 1.0, 0.0), n);
	u = dot(u, u) < 1e-6 ? vec3(1.0, 0.0, 0.0) : normalize(u);
	vec3 v = cross(n, u);
	vec2 q = vec2(dot(d, u), dot(d, v));
	if (hp.w < 0.5) {
		return length(q) - hs.x * 0.5;
	} else if (hp.w < 1.5) {
		return slot_sd(q, hs.x, hs.y);
	}
	return min(slot_sd(q, hs.x, hs.y), slot_sd(q.yx, hs.x, hs.y));
}

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
	mpos = VERTEX;
}

void fragment() {
	float edge = 1.0;
	for (int i = 0; i < MAX_HOLES; i++) {
		if (i >= hole_count) {
			break;
		}
		float sd = hole_sd(mpos, hole_pos[i], hole_nrm[i], hole_size[i]);
		if (sd < 0.0) {
			discard;
		}
		edge = min(edge, sd);
	}
	float m = fbm(wpos * 16.0);
	float grime = smoothstep(0.55, 0.78, fbm(wpos * 6.0 + vec3(3.1, 1.7, 5.3)));
	float fine = noise(wpos * 160.0);

	vec3 col = albedo.rgb * mix(1.0, 0.78 + 0.44 * m, patina);
	col *= 1.0 - patina * 0.3 * grime;
	// darken the cut edge a touch so holes read as punched through
	col *= mix(0.45, 1.0, smoothstep(0.0, 0.0016, edge));
	ALBEDO = col;
	METALLIC = metallic;
	if (preview_on) {
		// where the next hole would go: dark patch with a solid gold outline
		float ps = hole_sd(mpos, preview_pos, preview_nrm, preview_size);
		float ring = 1.0 - smoothstep(0.0006, 0.0018, abs(ps));
		float fill = ps < 0.0 ? 1.0 : 0.0;
		vec3 gold = vec3(1.0, 0.68, 0.18);
		ALBEDO = mix(ALBEDO, vec3(0.05, 0.04, 0.03), fill * 0.8);
		ALBEDO = mix(ALBEDO, gold, ring);
		METALLIC = METALLIC * (1.0 - ring) * (1.0 - fill * 0.85);
		ROUGHNESS = mix(ROUGHNESS, 0.9, max(ring, fill));
		EMISSION = gold * ring * 0.7;
	}
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
