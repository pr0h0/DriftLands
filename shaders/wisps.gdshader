// Thin translucent cloud layer drifting between the islands and the cloud sea.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 color : source_color = vec3(1.0, 0.9, 0.85);
uniform float opacity = 0.45;
uniform float scale = 0.02;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = fbm2(wpos.xz * scale + vec2(TIME * 0.008, -TIME * 0.005));
	ALBEDO = color;
	ALPHA = smoothstep(0.5, 0.75, n) * opacity;
}
