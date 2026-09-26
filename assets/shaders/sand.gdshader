shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform float floor_y = -96.0;
uniform vec4 sand_light : source_color = vec4(0.76, 0.68, 0.46, 1.0);
uniform vec4 sand_dark : source_color = vec4(0.48, 0.4, 0.26, 1.0);

varying vec3 wpos;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

float floor_h(vec2 xz) {
	float dune = fbm(xz * 0.018) * 1.05 + fbm(xz * 0.06 + 3.0) * 0.28;
	return floor_y + dune;
}

void vertex() {
	vec2 xz = VERTEX.xz;
	float h = floor_h(xz);
	VERTEX.y = h;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float e = 2.0;
	float hx = floor_h(xz + vec2(e, 0.0)) - h;
	float hz = floor_h(xz + vec2(0.0, e)) - h;
	NORMAL = normalize(vec3(-hx, e, -hz));
}

void fragment() {
	float grain = fbm(wpos.xz * 0.28);
	float patch = fbm(wpos.xz * 0.02 + 8.0);
	vec3 sand = mix(sand_dark.rgb, sand_light.rgb, patch);
	sand *= 0.88 + grain * 0.22;
	float caustic = noise(wpos.xz * 0.12 + vec2(TIME * 0.11, -TIME * 0.07));
	caustic *= noise(wpos.xz * 0.2 + vec2(-TIME * 0.08, TIME * 0.1));
	caustic = smoothstep(0.42, 0.72, caustic);
	ALBEDO = sand + vec3(0.07, 0.11, 0.05) * caustic;
	ROUGHNESS = 0.94;
}
