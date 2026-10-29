// MultiMesh grass blades: wind, player push, distance fade, up-facing normals for soft lighting.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, world_vertex_coords;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 root_color : source_color = vec3(0.14, 0.26, 0.07);
uniform vec3 tip_color : source_color = vec3(0.36, 0.54, 0.17);
uniform vec3 tip_color2 : source_color = vec3(0.5, 0.62, 0.22);
uniform vec3 player_pos = vec3(0.0, -1000.0, 0.0);
uniform float fade_start = 38.0;
uniform float fade_end = 60.0;
uniform bool flower = false;
uniform float grow = 1.0;
uniform vec3 stem_color : source_color = vec3(0.25, 0.42, 0.14);

varying float h;
varying vec3 wp;

void vertex() {
	h = UV.y;
	vec3 base = MODEL_MATRIX[3].xyz;
	float fade = 1.0 - smoothstep(fade_start, fade_end, distance(base, CAMERA_POSITION_WORLD));
	VERTEX.y = base.y + (VERTEX.y - base.y) * fade * grow;
	float gust = vnoise2(base.xz * 0.05 + vec2(TIME * 0.35, TIME * 0.2));
	float wind = sin(TIME * 1.9 + base.x * 0.35 + base.z * 0.25) * 0.4 + gust * 1.2 - 0.3;
	vec3 off = vec3(0.75, 0.0, 0.45) * wind * 0.22 * h * h;
	vec3 away = base - player_pos;
	float d = length(away.xz);
	float push = (1.0 - smoothstep(0.3, 1.3, d)) * step(abs(away.y), 1.6);
	off.xz += normalize(away.xz + vec2(0.001)) * push * 0.35 * h;
	off.y -= push * 0.18 * h;
	VERTEX += off;
	wp = base;
}

void fragment() {
	float patch = vnoise2(wp.xz * 0.06);
	vec3 tip = mix(tip_color, tip_color2, smoothstep(0.35, 0.75, patch));
	vec3 col = mix(root_color, tip, h) * COLOR.rgb;
	if (flower) {
		col = h > 0.8 ? COLOR.rgb : mix(root_color, stem_color, h);
	}
	ALBEDO = col;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	BACKLIGHT = col * 0.5 * h;
}
