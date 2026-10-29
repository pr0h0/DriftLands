// Sea of clouds below the islands: displaced, self-lit with a fake sun term.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 lit_color : source_color = vec3(1.0, 0.85, 0.7);
uniform vec3 shadow_color : source_color = vec3(0.45, 0.5, 0.7);
uniform vec3 sun_dir = vec3(0.3, 0.5, 0.2);
uniform float height = 12.0;
uniform float scale = 0.012;
uniform float speed = 0.01;

varying vec3 wn;
varying float hh;

float H(vec2 p) {
	float n = fbm2(p * scale + vec2(TIME * speed, TIME * speed * 0.6));
	return smoothstep(0.2, 0.85, n);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float e = 3.0;
	float h0 = H(w.xz);
	float hx = H(w.xz + vec2(e, 0.0));
	float hz = H(w.xz + vec2(0.0, e));
	VERTEX.y += h0 * height;
	wn = normalize(vec3(-(hx - h0) * height / e, 1.0, -(hz - h0) * height / e));
	hh = h0;
}

void fragment() {
	float l = clamp(dot(wn, normalize(sun_dir)) * 0.7 + 0.35, 0.0, 1.0);
	vec3 col = mix(shadow_color, lit_color, l);
	col *= mix(0.75, 1.05, hh);
	ALBEDO = col;
}
