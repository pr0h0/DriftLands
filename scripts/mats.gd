class_name Mats
## The art palette. Blender material names map to shaders/params here.

static var _cache: Dictionary = {}

const SURFACE := preload("res://shaders/surface.gdshader")
const FOLIAGE := preload("res://shaders/foliage.gdshader")


static func get_mat(mat_name: String) -> Material:
	if _cache.has(mat_name):
		return _cache[mat_name]
	var m := _build(mat_name)
	_cache[mat_name] = m
	return m


static func surface(params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func _build(mat_name: String) -> Material:
	match mat_name:
		"grass":
			return surface({"color_a": Color(0.30, 0.46, 0.15), "color_b": Color(0.42, 0.55, 0.19),
				"noise_scale": 0.06, "detail": 0.1})
		"grass_gold":
			return surface({"color_a": Color(0.55, 0.46, 0.18), "color_b": Color(0.66, 0.54, 0.22),
				"noise_scale": 0.06, "detail": 0.1})
		"soil":
			return surface({"color_a": Color(0.33, 0.23, 0.16), "color_b": Color(0.25, 0.17, 0.12),
				"noise_scale": 0.3, "strata": 0.3})
		"rock":
			return surface({"color_a": Color(0.52, 0.45, 0.39), "color_b": Color(0.37, 0.32, 0.29),
				"noise_scale": 0.12, "strata": 0.5, "strata_freq": 1.6,
				"top_color": Color(0.33, 0.47, 0.18), "top_amount": 0.85, "top_threshold": 0.55})
		"stone":
			return surface({"color_a": Color(0.82, 0.75, 0.64), "color_b": Color(0.70, 0.63, 0.54),
				"noise_scale": 0.35, "detail": 0.18,
				"top_color": Color(0.38, 0.5, 0.22), "top_amount": 0.45, "top_threshold": 0.72})
		"bark":
			return surface({"color_a": Color(0.36, 0.26, 0.19), "color_b": Color(0.25, 0.18, 0.13),
				"noise_scale": 1.2, "detail": 0.25})
		"wood":
			return surface({"color_a": Color(0.5, 0.36, 0.22), "color_b": Color(0.42, 0.3, 0.18), "noise_scale": 2.0})
		"leaf":
			var f := ShaderMaterial.new()
			f.shader = FOLIAGE
			return f
		"cloth":
			return surface({"color_a": Color(0.66, 0.15, 0.1), "color_b": Color(0.56, 0.11, 0.08),
				"noise_scale": 4.0, "detail": 0.08, "roughness_value": 0.85})
		"trim":
			return surface({"color_a": Color(0.92, 0.7, 0.3), "color_b": Color(0.85, 0.62, 0.25),
				"noise_scale": 6.0, "roughness_value": 0.45, "specular_value": 0.6})
		"cloth_dark":
			return surface({"color_a": Color(0.08, 0.05, 0.05), "color_b": Color(0.1, 0.06, 0.06)})
		"mask":
			return surface({"color_a": Color(0.94, 0.9, 0.82), "color_b": Color(0.9, 0.86, 0.78),
				"roughness_value": 0.45, "specular_value": 0.5})
		"eye":
			var e := StandardMaterial3D.new()
			e.albedo_color = Color(1.0, 0.9, 0.7)
			e.emission_enabled = true
			e.emission = Color(1.0, 0.82, 0.5)
			e.emission_energy_multiplier = 4.0
			return e
		"sail":
			var s := StandardMaterial3D.new()
			s.vertex_color_use_as_albedo = true
			s.cull_mode = BaseMaterial3D.CULL_DISABLED
			s.roughness = 0.9
			s.backlight_enabled = true
			s.backlight = Color(0.45, 0.35, 0.25)
			return s
		"rune":
			var r := StandardMaterial3D.new()
			r.albedo_color = Color(0.25, 0.27, 0.3)
			r.emission_enabled = true
			r.emission = Color(0.45, 0.85, 1.0)
			r.emission_energy_multiplier = 0.15
			return r
		"crystal":
			var c := StandardMaterial3D.new()
			c.albedo_color = Color(0.65, 0.9, 1.0)
			c.metallic = 0.2
			c.roughness = 0.15
			c.emission_enabled = true
			c.emission = Color(0.45, 0.82, 1.0)
			c.emission_energy_multiplier = 2.5
			c.rim_enabled = true
			c.rim = 0.6
			return c
		"grass_storm":
			return surface({"color_a": Color(0.27, 0.38, 0.24), "color_b": Color(0.33, 0.43, 0.27),
				"noise_scale": 0.06, "detail": 0.1})
		"rock_dark":
			return surface({"color_a": Color(0.3, 0.29, 0.32), "color_b": Color(0.2, 0.2, 0.23),
				"noise_scale": 0.12, "strata": 0.5, "strata_freq": 1.6,
				"top_color": Color(0.22, 0.3, 0.2), "top_amount": 0.7, "top_threshold": 0.55})
		"basalt":
			return surface({"color_a": Color(0.32, 0.31, 0.35), "color_b": Color(0.24, 0.23, 0.27),
				"noise_scale": 0.5, "detail": 0.2, "strata": 0.3, "strata_freq": 3.0,
				"top_color": Color(0.25, 0.32, 0.2), "top_amount": 0.4, "top_threshold": 0.8, "roughness_value": 0.7})
		"crumble":
			return surface({"color_a": Color(0.62, 0.52, 0.42), "color_b": Color(0.45, 0.36, 0.3),
				"noise_scale": 1.2, "detail": 0.35, "strata": 0.6, "strata_freq": 6.0})
		"mirror":
			var mr := StandardMaterial3D.new()
			mr.albedo_color = Color(0.85, 0.9, 1.0)
			mr.metallic = 1.0
			mr.roughness = 0.04
			mr.emission_enabled = true
			mr.emission = Color(0.25, 0.3, 0.35)
			return mr
		"eye_red":
			var er := StandardMaterial3D.new()
			er.albedo_color = Color(0.3, 0.05, 0.03)
			er.emission_enabled = true
			er.emission = Color(1.0, 0.3, 0.15)
			er.emission_energy_multiplier = 0.6
			return er
		"flowers":
			var fl := ShaderMaterial.new()
			fl.shader = preload("res://shaders/grass.gdshader")
			fl.set_shader_parameter("flower", true)
			return fl
		"stem":
			return surface({"color_a": Color(0.92, 0.88, 0.78), "color_b": Color(0.85, 0.8, 0.7), "noise_scale": 3.0})
		"cap":
			return surface({"color_a": Color(0.85, 0.35, 0.55), "color_b": Color(0.7, 0.25, 0.5), "noise_scale": 2.0,
				"roughness_value": 0.5, "emission_amount": 0.15})
		"grass_snow":
			return surface({"color_a": Color(0.88, 0.92, 0.98), "color_b": Color(0.78, 0.85, 0.95), "noise_scale": 0.08, "detail": 0.06})
		"rock_ice":
			return surface({"color_a": Color(0.5, 0.58, 0.7), "color_b": Color(0.36, 0.42, 0.55), "noise_scale": 0.12,
				"strata": 0.5, "strata_freq": 1.6, "top_color": Color(0.9, 0.94, 1.0), "top_amount": 0.9, "top_threshold": 0.5})
		"ice":
			var ic := StandardMaterial3D.new()
			ic.albedo_color = Color(0.7, 0.88, 1.0)
			ic.metallic = 0.1
			ic.roughness = 0.08
			ic.rim_enabled = true
			ic.rim = 0.7
			ic.emission_enabled = true
			ic.emission = Color(0.25, 0.45, 0.6)
			return ic
		"grass_sand":
			return surface({"color_a": Color(0.92, 0.78, 0.55), "color_b": Color(0.85, 0.7, 0.48), "noise_scale": 0.09, "detail": 0.08})
		"rock_sand":
			return surface({"color_a": Color(0.78, 0.5, 0.35), "color_b": Color(0.62, 0.38, 0.27), "noise_scale": 0.1,
				"strata": 0.85, "strata_freq": 2.2, "top_color": Color(0.9, 0.76, 0.52), "top_amount": 0.8, "top_threshold": 0.55})
		"grass_crystal":
			return surface({"color_a": Color(0.55, 0.5, 0.7), "color_b": Color(0.45, 0.42, 0.62), "noise_scale": 0.07, "detail": 0.1})
		"rock_crystal":
			return surface({"color_a": Color(0.3, 0.28, 0.42), "color_b": Color(0.2, 0.18, 0.3), "noise_scale": 0.15,
				"strata": 0.4, "top_color": Color(0.6, 0.55, 0.8), "top_amount": 0.6, "top_threshold": 0.6, "emission_amount": 0.08})
		"crystal_rock":
			var cr := StandardMaterial3D.new()
			cr.vertex_color_use_as_albedo = true
			cr.roughness = 0.15
			cr.metallic = 0.2
			cr.emission_enabled = true
			cr.emission = Color(0.45, 0.4, 0.75)
			cr.emission_energy_multiplier = 1.2
			cr.rim_enabled = true
			return cr
		"cactus":
			return surface({"color_a": Color(0.36, 0.55, 0.32), "color_b": Color(0.3, 0.48, 0.28), "noise_scale": 4.0, "strata": 0.6, "strata_freq": 18.0})
		"leaf_snow":
			var ls := ShaderMaterial.new()
			ls.shader = FOLIAGE
			ls.set_shader_parameter("snow", 0.85)
			return ls
		"scarf":
			var sc := ShaderMaterial.new()
			sc.shader = preload("res://shaders/scarf.gdshader")
			return sc
		"grass_blades", "grass_blades_gold", "grass_blades_storm", "grass_blades_snow", "grass_blades_sand", "grass_blades_crystal":
			var g := ShaderMaterial.new()
			g.shader = preload("res://shaders/grass.gdshader")
			if mat_name == "grass_blades_gold":
				g.set_shader_parameter("root_color", Color(0.28, 0.2, 0.06))
				g.set_shader_parameter("tip_color", Color(0.78, 0.62, 0.26))
				g.set_shader_parameter("tip_color2", Color(0.88, 0.74, 0.4))
			elif mat_name == "grass_blades_snow":
				g.set_shader_parameter("root_color", Color(0.55, 0.62, 0.7))
				g.set_shader_parameter("tip_color", Color(0.9, 0.94, 1.0))
				g.set_shader_parameter("tip_color2", Color(0.8, 0.88, 0.98))
			elif mat_name == "grass_blades_sand":
				g.set_shader_parameter("root_color", Color(0.55, 0.45, 0.25))
				g.set_shader_parameter("tip_color", Color(0.85, 0.75, 0.45))
				g.set_shader_parameter("tip_color2", Color(0.75, 0.68, 0.38))
			elif mat_name == "grass_blades_crystal":
				g.set_shader_parameter("root_color", Color(0.2, 0.15, 0.35))
				g.set_shader_parameter("tip_color", Color(0.65, 0.55, 0.95))
				g.set_shader_parameter("tip_color2", Color(0.5, 0.75, 0.95))
			elif mat_name == "grass_blades_storm":
				g.set_shader_parameter("root_color", Color(0.08, 0.14, 0.08))
				g.set_shader_parameter("tip_color", Color(0.24, 0.34, 0.2))
				g.set_shader_parameter("tip_color2", Color(0.3, 0.38, 0.24))
			return g
	return null
