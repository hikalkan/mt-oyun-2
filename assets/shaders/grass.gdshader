shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/noise.gdshaderinc"

varying vec3 wpos;
varying float slope;

float ground_h(vec2 xz) {
	return sin(xz.x * 0.02) * 2.2 + cos(xz.y * 0.017) * 1.8 + sin((xz.x + xz.y) * 0.008) * 3.0;
}

float river_z(float x) {
	return -16.0 + sin(x * 0.014) * 50.0;
}

void vertex() {
	vec2 xz = VERTEX.xz;
	float h = ground_h(xz);
	VERTEX.y = h;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float e = 0.8;
	float hx = ground_h(xz + vec2(e, 0.0)) - h;
	float hz = ground_h(xz + vec2(0.0, e)) - h;
	vec3 n = normalize(vec3(-hx, e, -hz));
	NORMAL = n;
	slope = clamp(1.0 - n.y, 0.0, 1.0);
}

void fragment() {
	float macro = fbm(wpos.xz * 0.01);
	float patch = fbm(wpos.xz * 0.045);
	float grain = noise(wpos.xz * 0.55);
	vec3 lush = vec3(0.16, 0.32, 0.12);
	vec3 fresh = vec3(0.28, 0.42, 0.16);
	vec3 dry = vec3(0.4, 0.38, 0.18);
	vec3 soil = vec3(0.34, 0.26, 0.15);
	vec3 grass = mix(lush, fresh, patch);
	grass = mix(grass, dry, smoothstep(0.48, 0.78, macro));
	grass = mix(grass, soil, smoothstep(0.04, 0.2, slope));
	float pebbles = smoothstep(0.74, 0.9, noise(wpos.xz * 1.7));
	grass = mix(grass, vec3(0.42, 0.4, 0.34), pebbles * 0.4);
	float bank = abs(wpos.z - river_z(wpos.x));
	float wet = smoothstep(12.0, 7.2, bank);
	grass = mix(grass, vec3(0.2, 0.24, 0.14), wet * 0.75);
	grass *= 0.9 + grain * 0.16;
	float e = 0.35;
	float h0 = noise(wpos.xz * 2.2);
	float hx = noise((wpos.xz + vec2(e, 0.0)) * 2.2) - h0;
	float hz = noise((wpos.xz + vec2(0.0, e)) * 2.2) - h0;
	NORMAL = normalize(NORMAL + mat3(VIEW_MATRIX) * vec3(hx, 0.0, hz) * 1.2);
	ALBEDO = grass;
	ROUGHNESS = mix(0.94, 0.62, wet * 0.45);
	SPECULAR = wet * 0.12;
}
