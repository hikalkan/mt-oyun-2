shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

void fragment() {
	float along = UV.x * 8.0 - TIME * 0.55;
	float across = UV.y;
	float center = smoothstep(0.0, 0.16, min(across, 1.0 - across));
	float wave = sin(along * 2.4 + across * 14.0) * 0.5 + 0.5;
	float rip = sin(along * 7.0 - across * 5.0 + TIME * 1.4) * 0.5 + 0.5;
	float foam = (1.0 - center) * (0.35 + 0.65 * rip);
	vec3 deep = vec3(0.03, 0.16, 0.28);
	vec3 mid_col = vec3(0.08, 0.32, 0.42);
	vec3 col = mix(mid_col, deep, center);
	col += vec3(0.05, 0.08, 0.07) * wave * center;
	col = mix(col, vec3(0.78, 0.86, 0.8), foam * 0.7);
	vec3 n = NORMAL;
	n.x += sin(along * 5.0) * 0.18;
	n.y += cos(along * 3.5 + across * 10.0) * 0.1;
	NORMAL = normalize(n);
	ALBEDO = col;
	ROUGHNESS = mix(0.16, 0.48, foam);
	SPECULAR = mix(0.72, 0.28, foam);
	ALPHA = mix(0.78, 0.96, center);
}
