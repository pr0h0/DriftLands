// Additive light column (updrafts, beacon). Brighter at the core, fades at both ends.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 color : source_color = vec3(0.6, 0.9, 1.0);
uniform float intensity = 1.0;
uniform float scroll = 0.6;
uniform float streaks = 1.0;

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float core = pow(facing, 2.0);
	float ends = smoothstep(0.0, 0.12, UV.y) * smoothstep(1.0, 0.7, UV.y);
	float s = mix(1.0, vnoise2(vec2(UV.x * 12.0, UV.y * 6.0 + TIME * scroll)), streaks);
	ALBEDO = color * intensity * core * ends * s;
}
