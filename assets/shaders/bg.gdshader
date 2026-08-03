shader_type canvas_item;
// 경매장 무드 배경: 네이비 그라데이션 + 천천히 흐르는 금빛 광원 + 비네트

void fragment() {
	vec2 uv = UV;
	vec3 top = vec3(0.085, 0.095, 0.145);
	vec3 bottom = vec3(0.045, 0.05, 0.082);
	vec3 col = mix(top, bottom, uv.y);

	vec2 light1 = vec2(0.5 + 0.28 * sin(TIME * 0.13), 0.22 + 0.05 * cos(TIME * 0.09));
	col += vec3(0.22, 0.17, 0.08) * smoothstep(0.75, 0.0, distance(uv, light1)) * 0.32;

	vec2 light2 = vec2(0.85 - 0.2 * sin(TIME * 0.07), 0.85);
	col += vec3(0.10, 0.09, 0.14) * smoothstep(0.6, 0.0, distance(uv, light2)) * 0.5;

	float vig = smoothstep(1.15, 0.45, distance(uv, vec2(0.5)));
	col *= mix(0.72, 1.0, vig);

	COLOR = vec4(col, 1.0);
}
