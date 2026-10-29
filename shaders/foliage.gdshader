// Leaves: vertex-color tint, wind sway scaled by height, translucent backlight.
shader_type spatial;
render_mode diffuse_burley;

#include "res://shaders/noise.gdshaderinc"

uniform float wind_strength = 0.06;
uniform float backlight_amount = 0.45;
uniform float snow = 0.0;

varying vec3 wpos;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = max(VERTEX.y, 0.0);
	float ph = origin.x * 0.21 + origin.z * 0.17;
	vec3 sway = vec3(sin(TIME * 1.3 + ph), 0.0, cos(TIME * 1.1 + ph * 1.3)) * wind_strength * h * 0.25;
	sway += vec3(sin(TIME * 4.0 + VERTEX.x * 3.0 + VERTEX.z * 2.0 + ph)) * 0.01 * h;
	VERTEX += sway;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = vnoise3(wpos * 2.5);
	float n = fbm3(wpos * 0.3);
	vec3 col = COLOR.rgb * (0.82 + 0.25 * d + 0.18 * n);
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	col = mix(col, vec3(0.92, 0.95, 1.0), smoothstep(0.2, 0.6, wn.y + (n - 0.5) * 0.4) * snow);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	BACKLIGHT = col * backlight_amount;
}
