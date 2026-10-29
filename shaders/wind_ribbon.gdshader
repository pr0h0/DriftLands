// Flowing wind band: dashes travel along UV.y, soft edges across UV.x, fades at both ends.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.85, 0.95, 1.0);
uniform float intensity = 0.6;
uniform float speed = 0.5;
uniform float dash = 5.0;

void fragment() {
	float d = fract(UV.y * dash - TIME * speed);
	float streak = smoothstep(0.0, 0.3, d) * smoothstep(1.0, 0.5, d);
	float edge = 1.0 - smoothstep(0.3, 1.0, abs(UV.x - 0.5) * 2.0);
	float ends = smoothstep(0.0, 0.08, UV.y) * smoothstep(1.0, 0.82, UV.y);
	ALBEDO = color * intensity * streak * edge * ends;
}
