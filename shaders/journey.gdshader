shader_type spatial;
render_mode cull_back, diffuse_burley, specular_disabled;

// 风之旅人风格：二段软渐变明暗 + 暖棕暗部 + 金色边缘光
uniform vec3 tint : source_color = vec3(0.85, 0.70, 0.55);
uniform vec3 shadow_color : source_color = vec3(0.55, 0.35, 0.24);
uniform vec3 rim_color : source_color = vec3(1.0, 0.85, 0.60);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.30;
uniform float rim_power : hint_range(1.0, 8.0) = 3.0;

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.9;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// 二段软渐变：大块明暗 + 提亮的受光面
	float ramp = smoothstep(-0.08, 0.30, ndl) * 0.55 + smoothstep(0.30, 0.85, ndl) * 0.45;
	// 暗部偏暖棕，亮部偏暖白，避免死灰
	vec3 base = mix(shadow_color * LIGHT_COLOR, ALBEDO * LIGHT_COLOR, ramp);
	DIFFUSE_LIGHT += base * ATTENUATION;
	// 金色边缘光（只在受光侧轻微出现）
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	DIFFUSE_LIGHT += rim_color * rim * rim_strength * ATTENUATION * (0.3 + 0.7 * ramp);
}
