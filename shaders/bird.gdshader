// Silhouette birds with flapping wing tips (per-instance phase).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 color : source_color = vec3(0.15, 0.12, 0.14);

void vertex() {
	float w = abs(VERTEX.x);
	VERTEX.y += sin(TIME * 9.0 + float(INSTANCE_ID) * 1.7) * 0.35 * w;
}

void fragment() {
	ALBEDO = color;
}
