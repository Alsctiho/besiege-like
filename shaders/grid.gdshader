shader_type spatial;
render_mode cull_back;

// 风之旅人沙地：暖沙底色 + 柔和浅色格线
uniform vec3 base_color : source_color = vec3(0.85, 0.52, 0.32);
uniform vec3 line_color : source_color = vec3(0.60, 0.37, 0.22);
uniform float cell_size = 0.5;
uniform float line_width = 0.032;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / cell_size;
	vec2 g = abs(fract(p + 0.5) - 0.5) * cell_size;
	float line = 1.0 - smoothstep(line_width * 0.5, line_width, min(g.x, g.y));
	// 微弱的大尺度明暗变化，模拟沙丘起伏
	float dune = sin(world_pos.x * 0.08) * cos(world_pos.z * 0.06) * 0.03;
	ALBEDO = mix(base_color, line_color, line * 0.7) + vec3(dune);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
