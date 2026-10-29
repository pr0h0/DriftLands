// Waterfall ribbon: streaks scrolling down, foamy top, fades into the clouds.
shader_type spatial;
render_mode cull_disabled, depth_draw_never, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 water : source_color = vec3(0.62, 0.82, 0.92);
uniform vec3 foam : source_color = vec3(0.95, 0.98, 1.0);

void fragment() {
	float s = vnoise2(vec2(UV.x * 14.0, UV.y * 7.0 - TIME * 3.2));
	float s2 = vnoise2(vec2(UV.x * 30.0 + 3.0, UV.y * 18.0 - TIME * 5.0));
	float streak = smoothstep(0.45, 0.85, s * 0.6 + s2 * 0.5);
	float edge = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	float top = 1.0 - smoothstep(0.0, 0.12, UV.y);
	ALBEDO = mix(water, foam, clamp(streak * 0.7 + top, 0.0, 1.0));
	EMISSION = ALBEDO * 0.15;
	ROUGHNESS = 0.2;
	ALPHA = edge * (0.55 + streak * 0.4) * (1.0 - smoothstep(0.6, 1.0, UV.y));
}
