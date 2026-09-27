shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

varying vec3 wpos;
varying float slope;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

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
	float patch = noise(wpos.xz * 0.035);
	float grain = noise(wpos.xz * 0.32);
	vec3 low = vec3(0.2, 0.4, 0.13);
	vec3 high = vec3(0.46, 0.66, 0.26);
	vec3 dirt = vec3(0.4, 0.32, 0.16);
	vec3 grass = mix(low, high, patch);
	grass = mix(grass, dirt, smoothstep(0.04, 0.16, slope));
	float bank = abs(wpos.z - river_z(wpos.x));
	float wet = smoothstep(12.0, 7.2, bank);
	grass = mix(grass, vec3(0.24, 0.3, 0.16), wet * 0.7);
	grass *= 0.9 + grain * 0.18;
	ALBEDO = grass;
	ROUGHNESS = 0.96;
}
