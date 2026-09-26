shader_type spatial;
render_mode diffuse_burley, specular_disabled;

uniform float half_extent = 260.0;
uniform float shelf_y = -78.0;
uniform float bed_y = -170.0;
uniform float shelf_start = 0.18;
uniform float shelf_end = 0.9;
uniform vec4 sand_light : source_color = vec4(0.74, 0.66, 0.48, 1.0);
uniform vec4 sand_dark : source_color = vec4(0.4, 0.36, 0.26, 1.0);
uniform vec4 sand_deep : source_color = vec4(0.12, 0.16, 0.18, 1.0);

varying float depth_t;
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
	float r = length(xz) / half_extent;
	float t = smoothstep(shelf_start, shelf_end, r);
	float dune = fbm(xz * 0.03) * 1.15 + fbm(xz * 0.08 + 3.0) * 0.32;
	return mix(shelf_y, bed_y, t) + dune * (1.0 - t * 0.7);
}

void vertex() {
	vec2 xz = VERTEX.xz;
	float h = floor_h(xz);
	VERTEX.y = h;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float e = 1.6;
	float hx = floor_h(xz + vec2(e, 0.0)) - h;
	float hz = floor_h(xz + vec2(0.0, e)) - h;
	NORMAL = normalize(vec3(-hx, e, -hz));
	float r = length(xz) / half_extent;
	depth_t = smoothstep(shelf_start, shelf_end, r);
}

void fragment() {
	float grain = fbm(wpos.xz * 0.32);
	float patch = fbm(wpos.xz * 0.035 + 8.0);
	vec3 sand = mix(sand_dark.rgb, sand_light.rgb, patch);
	sand *= 0.86 + grain * 0.28;
	vec3 col = mix(sand, sand_deep.rgb, depth_t);
	float caustic = noise(wpos.xz * 0.16 + vec2(TIME * 0.11, -TIME * 0.07));
	caustic *= noise(wpos.xz * 0.25 + vec2(-TIME * 0.08, TIME * 0.1));
	caustic = smoothstep(0.45, 0.74, caustic);
	col += vec3(0.09, 0.13, 0.07) * caustic * (1.0 - depth_t);
	ALBEDO = col;
	ROUGHNESS = mix(0.9, 1.0, depth_t);
}
