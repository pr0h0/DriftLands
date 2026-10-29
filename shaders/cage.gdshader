// Shimmering seal bubble around a locked shard. `dissolve` 0..1 burns it away.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0, 0.75, 0.4);
uniform float dissolve = 0.0;

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	vec2 uv = UV * vec2(24.0, 12.0);
	vec2 g = abs(fract(uv + vec2(0.0, TIME * 0.2)) - 0.5);
	float lines = smoothstep(0.44, 0.5, max(g.x, g.y));
	float n = vnoise2(UV * 30.0 + TIME * 0.5);
	float keep = step(dissolve, n * 0.95 + 0.02);
	float edge = (1.0 - smoothstep(0.0, 0.08, n - dissolve)) * step(0.001, dissolve);
	ALBEDO = (color * (fres * 1.4 + lines * 0.35 + 0.05) + vec3(1.0, 0.9, 0.7) * edge * 3.0) * keep;
}
