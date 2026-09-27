shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://assets/shaders/noise.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.35, 0.24, 0.12, 1.0);
uniform float roughness_amt : hint_range(0.0, 1.0) = 0.86;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rings = noise(vec2(wpos.y * 2.4, wpos.x * 0.35 + wpos.z * 0.35));
	float cracks = smoothstep(0.58, 0.82, noise(vec2(wpos.y * 0.7, atan(wpos.x, wpos.z) * 1.6)));
	vec3 col = albedo.rgb * (0.72 + rings * 0.45);
	col = mix(col, col * 0.45, cracks * 0.55);
	float e = 0.08;
	float h0 = noise(vec2(wpos.y * 4.0, wpos.x + wpos.z));
	float hy = noise(vec2((wpos.y + e) * 4.0, wpos.x + wpos.z)) - h0;
	NORMAL = normalize(NORMAL + vec3(0.0, hy * 1.4, 0.0));
	ALBEDO = col;
	ROUGHNESS = clamp(roughness_amt, 0.7, 1.0);
	SPECULAR = 0.04;
}
