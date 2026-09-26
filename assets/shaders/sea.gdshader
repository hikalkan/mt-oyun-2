shader_type canvas_item;

uniform float surface_y = 280.0;
uniform float sand_y = 2100.0;

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

float shaft(float x, float spacing, float width, float drift) {
	float u = fract((x + drift) / spacing);
	float d = abs(u - 0.5);
	return smoothstep(width, width * 0.22, d);
}

void fragment() {
	float y = world_pos.y;
	float wave = sin(world_pos.x * 0.012 + TIME * 1.05) * 14.0;
	wave += sin(world_pos.x * 0.028 + TIME * 0.62 + 1.7) * 6.0;
	float surface = surface_y + wave;
	vec3 col;

	if (y < surface) {
		float t = clamp(y / max(surface, 1.0), 0.0, 1.0);
		col = mix(vec3(0.38, 0.66, 0.95), vec3(0.72, 0.89, 0.99), t);
		float sd = distance(world_pos, vec2(980.0, 62.0));
		col += vec3(1.0, 0.94, 0.68) * smoothstep(100.0, 0.0, sd);
		col += vec3(1.0, 0.78, 0.4) * smoothstep(240.0, 20.0, sd) * 0.3;
		float cloud = sin(world_pos.x * 0.008 + 0.6) * sin(world_pos.x * 0.003 + world_pos.y * 0.02);
		col = mix(col, vec3(1.0), smoothstep(0.25, 0.9, cloud) * (1.0 - t) * 0.45);
	} else if (y > sand_y) {
		float st = clamp((y - sand_y) / 260.0, 0.0, 1.0);
		col = mix(vec3(0.84, 0.75, 0.50), vec3(0.58, 0.48, 0.32), st);
		float cau = sin(world_pos.x * 0.025 + TIME * 0.9) * sin(world_pos.y * 0.03 - TIME * 0.55);
		cau = smoothstep(0.05, 0.8, cau * 0.5 + 0.5);
		col += vec3(0.2, 0.15, 0.05) * cau * 0.4;
	} else {
		float depth = clamp((y - surface) / (sand_y - surface), 0.0, 1.0);
		vec3 shallow_c = vec3(0.12, 0.75, 0.86);
		vec3 mid_c = vec3(0.04, 0.33, 0.68);
		vec3 deep_c = vec3(0.012, 0.055, 0.16);
		col = mix(shallow_c, mid_c, smoothstep(0.0, 0.4, depth));
		col = mix(col, deep_c, smoothstep(0.28, 1.0, depth));

		float fade = pow(1.0 - depth, 1.5);
		float slant = world_pos.x + (y - surface) * 0.28;
		float drift = sin(TIME * 0.18) * 40.0;
		float rays = shaft(slant, 820.0, 0.075, drift);
		rays += shaft(slant + 260.0, 1100.0, 0.05, -drift * 0.7) * 0.75;
		rays += shaft(slant - 140.0, 540.0, 0.028, drift * 1.4) * 0.45;
		col += vec3(0.62, 0.86, 0.95) * min(rays, 1.5) * fade * 0.38;

		float cau = sin(world_pos.x * 0.018 + TIME * 0.65) * sin(world_pos.y * 0.016 + TIME * 0.4);
		cau = smoothstep(0.25, 0.95, cau * 0.5 + 0.5);
		col += vec3(0.3, 0.5, 0.55) * cau * fade * 0.26;

		float below = y - surface;
		if (below < 80.0) {
			col += vec3(0.2, 0.35, 0.32) * (1.0 - below / 80.0) * 0.4;
		}
	}

	float foam = 1.0 - smoothstep(0.0, 12.0, abs(y - surface));
	col = mix(col, vec3(0.93, 0.98, 1.0), foam * 0.92);
	COLOR = vec4(col, 1.0);
}
