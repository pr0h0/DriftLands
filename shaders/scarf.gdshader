// Flowing scarf ribbon with faintly glowing gold glyph bands.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec3 base_color : source_color = vec3(0.72, 0.16, 0.1);
uniform vec3 glyph_color : source_color = vec3(1.0, 0.78, 0.35);

void fragment() {
	float band = step(0.82, fract(UV.y * 5.0)) * step(0.25, UV.x) * step(UV.x, 0.75);
	ALBEDO = mix(base_color, glyph_color, band);
	EMISSION = glyph_color * band * 0.8;
	ROUGHNESS = 0.8;
	BACKLIGHT = base_color * 0.4;
}
