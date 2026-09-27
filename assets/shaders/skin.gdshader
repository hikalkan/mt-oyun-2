shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.4, 0.45, 0.22, 1.0);
uniform float roughness_amt : hint_range(0.0, 1.0) = 0.55;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float nx = abs(wnorm.x);
	float ny = abs(wnorm.y);
	float nz = abs(wnorm.z);
	float nsum = max(nx + ny + nz, 0.001);
	float detail = (fbm(wpos.yz * 2.6) * nx + fbm(wpos.xz * 2.6) * ny + fbm(wpos.xy * 2.6) * nz) / nsum;
	float scales = noise(wpos.xz * 5.5 + wpos.y * 2.2);
	float mottling = noise(wpos.xz * 0.28 + wpos.y * 0.05);
	vec3 col = albedo.rgb;
	col *= 0.76 + detail * 0.4;
	col = mix(col, col * vec3(0.8, 0.88, 0.68), mottling * 0.4);
	float belly = smoothstep(0.2, -0.55, wnorm.y);
	col = mix(col, col * vec3(1.22, 1.14, 0.92), belly * 0.42);
	float back = smoothstep(0.15, 0.85, wnorm.y);
	col = mix(col, col * vec3(0.7, 0.76, 0.6), back * 0.38);
	float e = 0.1;
	float h0 = noise(wpos.xz * 7.0 + wpos.y * 2.0);
	float hx = noise((wpos.xz + vec2(e, 0.0)) * 7.0 + wpos.y * 2.0) - h0;
	float hz = noise((wpos.xz + vec2(0.0, e)) * 7.0 + wpos.y * 2.0) - h0;
	NORMAL = normalize(NORMAL + mat3(VIEW_MATRIX) * vec3(hx, scales * 0.04, hz) * 1.8);
	ALBEDO = col;
	ROUGHNESS = clamp(roughness_amt + (scales - 0.5) * 0.22, 0.26, 0.94);
	SPECULAR = 0.26;
}
