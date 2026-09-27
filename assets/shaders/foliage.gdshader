shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.2, 0.45, 0.16, 1.0);
uniform float roughness_amt : hint_range(0.0, 1.0) = 0.72;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float clump = fbm(wpos.xz * 0.9 + wpos.y * 0.4);
	float speckle = noise(wpos.xz * 3.2 + wpos.y);
	vec3 deep = albedo.rgb * vec3(0.55, 0.62, 0.45);
	vec3 lit = albedo.rgb * vec3(1.15, 1.2, 0.85);
	vec3 col = mix(deep, lit, clump);
	col = mix(col, col * vec3(1.05, 1.12, 0.7), speckle * 0.35);
	float underside = smoothstep(0.1, -0.6, wnorm.y);
	col = mix(col, col * vec3(0.7, 0.85, 0.55), underside * 0.45);
	ALBEDO = col;
	ROUGHNESS = clamp(roughness_amt, 0.45, 0.95);
	SPECULAR = 0.08;
}
