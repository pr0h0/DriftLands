// Gloom wisp body: a wobbling knot of ink with a swirling violet core and a bright rim.
shader_type spatial;
render_mode unshaded, depth_draw_always;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 rim_color : source_color = vec3(0.65, 0.35, 1.0);
uniform vec3 core_color : source_color = vec3(0.35, 0.1, 0.6);
uniform float alpha = 1.0;
uniform float agitation = 0.0;  // 0 calm .. 1 furious (chasing / winding up)

varying vec3 lpos;

void vertex() {
	float n = vnoise3(VERTEX * 3.0 + vec3(0.0, TIME * (1.2 + agitation * 3.0), 0.0));
	float back = smoothstep(0.05, 0.45, VERTEX.z);  // +Z is behind: the trailing side stretches into a tail
	float front = smoothstep(-0.1, -0.45, VERTEX.z);  // keep the face calm so the eyes stay visible
	VERTEX += NORMAL * (n - 0.5) * (0.12 + agitation * 0.1) * (1.0 - front * 0.8);
	VERTEX.z += back * (0.35 + 0.15 * sin(TIME * 4.0 + VERTEX.x * 6.0));
	lpos = VERTEX;
}

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.6);
	float swirl = vnoise3(vec3(lpos.xy * 5.0, TIME * 1.5) + vec3(sin(TIME + lpos.z * 4.0)));
	vec3 inner = mix(vec3(0.008, 0.0, 0.018), core_color, smoothstep(0.62, 0.9, swirl) * (0.35 + agitation));
	ALBEDO = mix(inner, rim_color * (2.0 + agitation * 1.5), fres);
	ALPHA = alpha;
}
