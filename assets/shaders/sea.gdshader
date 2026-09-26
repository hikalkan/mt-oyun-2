shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.012, 0.14, 0.28, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.04, 0.38, 0.55, 1.0);
uniform vec4 foam_color : source_color = vec4(0.8, 0.91, 0.96, 1.0);
uniform vec3 sun_dir = vec3(0.45, 0.74, 0.32);

varying float wave_h;

void vertex() {
	vec3 p = VERTEX;
	float w1 = sin(p.x * 0.034 + TIME * 0.46) * 0.85;
	float w2 = sin(p.z * 0.024 + TIME * 0.33 + 1.7) * 0.62;
	float w3 = sin((p.x * 0.65 + p.z) * 0.052 + TIME * 0.7) * 0.24;
	float w4 = sin((p.x - p.z * 1.25) * 0.086 + TIME * 1.1) * 0.1;
	float h = w1 + w2 + w3 + w4;
	VERTEX.y += h;
	wave_h = h;
	float dx = cos(p.x * 0.034 + TIME * 0.46) * 0.85 * 0.034;
	dx += cos((p.x * 0.65 + p.z) * 0.052 + TIME * 0.7) * 0.24 * 0.052 * 0.65;
	dx += cos((p.x - p.z * 1.25) * 0.086 + TIME * 1.1) * 0.1 * 0.086;
	float dz = cos(p.z * 0.024 + TIME * 0.33 + 1.7) * 0.62 * 0.024;
	dz += cos((p.x * 0.65 + p.z) * 0.052 + TIME * 0.7) * 0.24 * 0.052;
	dz += cos((p.x - p.z * 1.25) * 0.086 + TIME * 1.1) * 0.1 * 0.086 * -1.25;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	vec3 l = normalize(sun_dir);
	float ndotv = clamp(dot(n, v), 0.0, 1.0);
	float fres = pow(1.0 - ndotv, 3.4);
	vec3 half_dir = normalize(l + v);
	float ndoth = clamp(dot(n, half_dir), 0.0, 1.0);
	float spec = pow(ndoth, 80.0);
	float glitter = pow(ndoth, 260.0);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, clamp(fres * 0.8 + 0.08, 0.0, 1.0));
	float crest = smoothstep(0.75, 1.45, wave_h);
	float foam = crest * 0.5 + pow(fres, 5.0) * 0.16;
	col = mix(col, foam_color.rgb, clamp(foam, 0.0, 0.62));
	col += vec3(0.95, 0.97, 1.0) * (spec * 0.5 + glitter * 0.75);
	ALBEDO = col;
	ALPHA = mix(0.55, 0.92, fres);
	ROUGHNESS = mix(0.05, 0.32, 1.0 - fres);
	SPECULAR = 0.55;
	METALLIC = 0.04;
}
