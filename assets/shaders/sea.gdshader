shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 water_color : source_color = vec4(0.05, 0.45, 0.72, 0.72);
uniform vec4 foam_color : source_color = vec4(0.82, 0.94, 1.0, 0.9);

void vertex() {
	vec3 p = VERTEX;
	float h = sin(p.x * 0.42 + TIME * 1.25) * 0.16;
	h += sin(p.z * 0.33 + TIME * 0.85 + 1.4) * 0.12;
	VERTEX.y += h;
	float dx = cos(p.x * 0.42 + TIME * 1.25) * 0.16 * 0.42;
	float dz = cos(p.z * 0.33 + TIME * 0.85 + 1.4) * 0.12 * 0.33;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 col = mix(water_color.rgb, foam_color.rgb, fres * 0.62);
	ALBEDO = col;
	ALPHA = mix(water_color.a, 0.88, fres);
	ROUGHNESS = 0.18;
}
