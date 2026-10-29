// Ridable sky-stone: dark slate with an engraved rune circle on top and glowing edges.
// Pattern uses local coordinates, so it travels with the platform.
shader_type spatial;
render_mode diffuse_burley;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.24, 0.26, 0.32);
uniform vec3 glow_color : source_color = vec3(1.0, 0.78, 0.4);
uniform float glow = 2.2;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	float n = fbm3(lp * 1.4);
	vec3 col = base_color * (0.8 + 0.4 * n);
	float top = smoothstep(0.6, 0.9, ln.y);
	float r = length(lp.xz);
	float ang = atan(lp.z, lp.x);
	// Engraved rings and radial ticks on the walking surface.
	float ring1 = 1.0 - smoothstep(0.03, 0.07, abs(r - 1.45));
	float ring2 = 1.0 - smoothstep(0.02, 0.05, abs(r - 0.75));
	float ticks = (1.0 - smoothstep(0.04, 0.1, abs(fract(ang / 6.2831853 * 12.0) - 0.5) * 2.0 * r * 0.26)) * step(0.8, r) * step(r, 1.4);
	float dot_c = 1.0 - smoothstep(0.12, 0.18, r);
	float pattern = clamp(ring1 + ring2 + ticks * 0.8 + dot_c, 0.0, 1.0) * top;
	// Glowing rim where the top meets the sides.
	float rim = (1.0 - abs(ln.y)) * smoothstep(-0.25, 0.0, lp.y);
	float pulse = 0.75 + 0.25 * sin(TIME * 2.0);
	col = mix(col, glow_color * 0.6, pattern * 0.6);
	ALBEDO = col;
	ROUGHNESS = 0.7;
	EMISSION = glow_color * (pattern * glow * pulse + rim * 0.5);
}
