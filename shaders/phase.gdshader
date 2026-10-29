// Day/night platforms: solid when present, a faint glowing ghost when absent.
shader_type spatial;
render_mode diffuse_burley, cull_back, depth_prepass_alpha;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.55, 0.6, 0.75);
uniform vec3 glow_color : source_color = vec3(0.5, 0.85, 1.0);
uniform float presence = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = fbm3(wpos * 0.6);
	float veins = smoothstep(0.47, 0.5, abs(fract(n * 6.0) - 0.5) * 2.0 - 0.45);
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	ALBEDO = base_color * (0.8 + 0.3 * n) * COLOR.rgb;
	EMISSION = glow_color * (veins * 1.5 + fres * (1.5 - presence)) * (0.3 + 0.7 * presence);
	ALPHA = mix(0.14, 1.0, presence);
	ROUGHNESS = 0.6;
}
