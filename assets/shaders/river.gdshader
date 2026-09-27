shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, unshaded;

void fragment() {
	float flow = sin(UV.x * 16.0 - TIME * 2.6) * 0.5 + 0.5;
	float ripple = sin(UV.y * 28.0 + UV.x * 6.0 + TIME * 1.8) * 0.5 + 0.5;
	vec3 deep = vec3(0.06, 0.32, 0.68);
	vec3 light = vec3(0.55, 0.84, 0.95);
	ALBEDO = mix(deep, light, flow * 0.42 + ripple * 0.22);
	ALPHA = 0.9;
}
