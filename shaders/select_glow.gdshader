shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

// Gold rim glow drawn over a selected piece.
uniform vec4 glow : source_color = vec4(1.0, 0.72, 0.25, 1.0);

void fragment() {
	float f = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
	float pulse = 0.75 + 0.25 * sin(TIME * 4.0);
	ALBEDO = glow.rgb * f * 0.9 * pulse;
}
