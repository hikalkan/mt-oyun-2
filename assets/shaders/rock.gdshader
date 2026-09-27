shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.45, 0.44, 0.4, 1.0);
uniform float roughness_amt : hint_range(0.0, 1.0) = 0.9;

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
	float grain = (fbm(wpos.yz * 1.1) * nx + fbm(wpos.xz * 1.1) * ny + fbm(wpos.xy * 1.1) * nz) / nsum;
	float crack = smoothstep(0.62, 0.84, noise(wpos.xz * 1.3 + wpos.y * 0.4));
	vec3 col = albedo.rgb * (0.68 + grain * 0.5);
	col = mix(col, col * 0.42, crack * 0.65);
	ALBEDO = col;
	ROUGHNESS = clamp(roughness_amt, 0.75, 1.0);
	SPECULAR = 0.06;
}
