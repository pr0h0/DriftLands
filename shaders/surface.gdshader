// Stylized world-space surface: two-tone noise, optional strata and moss on up-facing faces.
shader_type spatial;
render_mode diffuse_burley;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 color_a : source_color = vec3(0.5);
uniform vec3 color_b : source_color = vec3(0.4);
uniform float noise_scale = 0.2;
uniform float detail = 0.15;
uniform float vertex_color_amount = 1.0;
uniform float strata = 0.0;
uniform float strata_freq = 1.2;
uniform vec3 top_color : source_color = vec3(0.35, 0.55, 0.2);
uniform float top_amount = 0.0;
uniform float top_threshold = 0.6;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;
uniform float specular_value : hint_range(0.0, 1.0) = 0.3;
uniform float emission_amount = 0.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n = fbm3(wpos * noise_scale);
	float d = vnoise3(wpos * noise_scale * 7.0);
	vec3 col = mix(color_a, color_b, smoothstep(0.35, 0.65, n));
	col *= 1.0 - detail + detail * 2.0 * d;
	if (strata > 0.0) {
		float s = sin(wpos.y * strata_freq + n * 5.0) * 0.5 + 0.5;
		col *= mix(1.0, 0.8 + 0.3 * s, strata);
	}
	col *= mix(vec3(1.0), COLOR.rgb, vertex_color_amount);
	float up = smoothstep(top_threshold, top_threshold + 0.2, normalize(wnorm).y + (n - 0.5) * 0.5);
	col = mix(col, top_color * (0.85 + 0.3 * d), up * top_amount);
	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	EMISSION = col * emission_amount;
}
