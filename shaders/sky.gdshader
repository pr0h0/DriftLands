// Stylized sky: gradient, sun disk + halo, procedural high clouds, stars and moon at night.
shader_type sky;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 zenith : source_color = vec3(0.2, 0.4, 0.8);
uniform vec3 horizon : source_color = vec3(0.9, 0.75, 0.6);
uniform vec3 below : source_color = vec3(0.6, 0.65, 0.75);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.8, 0.6);
uniform vec3 sun_dir = vec3(0.0, 0.3, -1.0);
uniform float day = 1.0;
uniform float cloud_amount = 0.38;
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.9, 0.8);
uniform vec3 cloud_dark : source_color = vec3(0.5, 0.55, 0.7);
uniform float flash = 0.0;
uniform float aurora = 0.0;

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 sd = normalize(sun_dir);
	float sdot = max(dot(d, sd), 0.0);
	float up = clamp(h, 0.0, 1.0);
	vec3 col = mix(horizon, zenith, pow(up, 0.45));
	col = mix(col, below, smoothstep(0.0, 0.35, clamp(-h, 0.0, 1.0)));
	col += sun_tint * pow(sdot, 6.0) * 0.5 * (1.0 - up) * clamp(day * 1.5, 0.0, 1.0);

	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 1.1;
		float c = fbm2(uv + vec2(TIME * 0.004, TIME * 0.002));
		float cm = smoothstep(1.0 - cloud_amount, 1.0 - cloud_amount + 0.28, c) * smoothstep(0.0, 0.18, h);
		float lit = clamp(pow(sdot, 3.0) * 0.7 + 0.35 + (c - 0.5) * 0.8, 0.0, 1.0);
		col = mix(col, mix(cloud_dark, cloud_lit, lit), cm * 0.8);
	}

	col += sun_tint * smoothstep(0.9993, 0.9997, sdot) * 16.0 * day;
	col += sun_tint * pow(sdot, 220.0) * 1.2 * day;

	float night = 1.0 - day;
	if (night > 0.0) {
		vec3 cell = floor(d * 260.0);
		float s = hash13(cell);
		float star = step(0.9982, s) * smoothstep(0.0, 0.25, h);
		col += vec3(star) * night * (1.2 + 0.8 * sin(TIME * 2.0 + s * 100.0));
		float md = max(dot(d, -sd), 0.0);
		col += vec3(0.9, 0.95, 1.0) * smoothstep(0.9990, 0.9994, md) * night * 3.0;
		col += vec3(0.3, 0.4, 0.6) * pow(md, 40.0) * night * 0.4;
	}
	if (aurora > 0.0 && h > 0.0) {
		vec2 p = d.xz / (h + 0.25);
		float curtain = 0.0;
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float band = p.x * (0.9 + fi * 0.3) + sin(p.y * 1.3 + TIME * 0.12 + fi * 2.0) * 0.6 + fi * 1.7;
			curtain += pow(1.0 - abs(sin(band * 1.4)), 10.0) * vnoise2(vec2(p.y * 3.0 + fi, TIME * 0.3));
		}
		float vert = smoothstep(0.05, 0.3, h) * (1.0 - smoothstep(0.55, 0.9, h));
		vec3 ac = mix(vec3(0.2, 1.0, 0.6), vec3(0.6, 0.35, 1.0), smoothstep(0.2, 0.6, h));
		col += ac * curtain * vert * aurora * (1.0 - day) * 1.6;
	}
	col += vec3(0.75, 0.8, 1.0) * flash * (0.6 + 0.4 * up);
	COLOR = col;
}
