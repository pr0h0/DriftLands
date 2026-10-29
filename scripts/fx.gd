class_name FX
## Small particle/visual effect builders.


static func _fade_ramp(peak := 1.0) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, peak))
	g.add_point(0.75, Color(1, 1, 1, peak))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static var _soft_tex: GradientTexture2D


## Soft round dot so particles read as glows instead of hard squares.
static func soft_texture() -> GradientTexture2D:
	if _soft_tex == null:
		_soft_tex = GradientTexture2D.new()
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.75))
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(0.5, 0.0)
		_soft_tex.width = 64
		_soft_tex.height = 64
	return _soft_tex


static func _additive(color: Color, billboard: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if billboard == BaseMaterial3D.BILLBOARD_PARTICLES:
		m.albedo_texture = soft_texture()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = billboard
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	m.disable_receive_shadows = true
	return m


## Rising wind streaks for updrafts.
static func streaks(radius: float, height: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = radius
	pm.emission_ring_inner_radius = radius * 0.2
	pm.emission_ring_height = 1.0
	pm.direction = Vector3.UP
	pm.spread = 4.0
	pm.initial_velocity_min = 10.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3.ZERO
	pm.color_ramp = _fade_ramp(0.6)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 1.8)
	q.material = _additive(Color(1, 1, 1, 0.5), BaseMaterial3D.BILLBOARD_FIXED_Y)
	p.draw_pass_1 = q
	p.amount = 70
	p.lifetime = height / 13.0
	p.preprocess = p.lifetime
	p.visibility_aabb = AABB(Vector3(-radius - 2, -2, -radius - 2), Vector3(radius * 2 + 4, height + 6, radius * 2 + 4))
	return p


## Drifting light motes that follow the player (local_coords off so they stay in the world).
static func motes() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 8, 22)
	pm.direction = Vector3(0.3, 0.2, 0.1)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 0.02, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color_ramp = _fade_ramp(0.8)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	q.material = _additive(Color(1.0, 0.92, 0.75, 0.8), BaseMaterial3D.BILLBOARD_PARTICLES)
	p.draw_pass_1 = q
	p.amount = 260
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-30, -12, -30), Vector3(60, 24, 60))
	return p


## Sparkles around a shard; with local_coords off they leave a trail when it moves.
static func sparkles(color: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, 0.4, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	pm.color_ramp = _fade_ramp(1.0)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	q.material = _additive(color, BaseMaterial3D.BILLBOARD_PARTICLES)
	p.draw_pass_1 = q
	p.amount = 40
	p.lifetime = 1.6
	p.local_coords = false
	return p


static func beam(radius: float, height: float, color: Color, intensity: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.cap_top = false
	c.cap_bottom = false
	c.radial_segments = 24
	mi.mesh = c
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/beam.gdshader")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("intensity", intensity)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = height / 2.0
	return mi


## Puff of dust when landing hard.
static func dust() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.4
	pm.emission_ring_inner_radius = 0.2
	pm.emission_ring_height = 0.05
	pm.direction = Vector3(0, 0.3, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, -1.0, 0)
	pm.damping_min = 3.0
	pm.damping_max = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.color_ramp = _fade_ramp(0.5)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	var m := _additive(Color(0.9, 0.85, 0.75, 0.35), BaseMaterial3D.BILLBOARD_PARTICLES)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	q.material = m
	p.draw_pass_1 = q
	p.amount = 18
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	p.local_coords = false
	return p


## Rain streaks; parent follows the player.
static func rain(amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(30, 1, 30)
	pm.direction = Vector3(0.08, -1, 0.04)
	pm.spread = 2.0
	pm.initial_velocity_min = 28.0
	pm.initial_velocity_max = 34.0
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.9)
	q.material = _additive(Color(0.75, 0.8, 0.95, 0.35), BaseMaterial3D.BILLBOARD_FIXED_Y)
	p.draw_pass_1 = q
	p.amount = amount
	p.lifetime = 1.6
	p.preprocess = 1.6
	p.local_coords = false
	p.position.y = 24.0
	p.visibility_aabb = AABB(Vector3(-35, -60, -35), Vector3(70, 70, 70))
	return p


## Big soft glowing lanterns/fireflies drifting around a point.
static func lanterns(extents: Vector3, color: Color, amount := 60) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, 0.05, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.color_ramp = _fade_ramp(1.0)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	q.material = _additive(color, BaseMaterial3D.BILLBOARD_PARTICLES)
	p.draw_pass_1 = q
	p.amount = amount
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.visibility_aabb = AABB(-extents - Vector3.ONE * 4, extents * 2 + Vector3.ONE * 8)
	return p


## Fluttering butterflies over a meadow.
static func butterflies(extents: Vector3) -> GPUParticles3D:
	var p := lanterns(extents, Color(1, 1, 1, 1), 14)
	var pm := p.process_material as ParticleProcessMaterial
	pm.turbulence_noise_strength = 2.5
	pm.turbulence_noise_speed_random = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.3))
	g.set_color(1, Color(0.95, 0.55, 0.85))
	g.add_point(0.5, Color(0.6, 0.85, 1.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_initial_ramp = gt
	var q := p.draw_pass_1 as QuadMesh
	q.size = Vector2(0.14, 0.1)
	var m := q.material as StandardMaterial3D
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_color = Color(1, 1, 1, 1)
	return p


## Wind ribbon strips. `paths` is an Array of PackedVector3Array (local points); bands are
## `width` wide along `up`. UV.y runs along each path, so dashes flow from first to last point.
static func ribbons(paths: Array, width: float, up: Vector3, color: Color, intensity := 0.6, speed := 0.5, dash := 5.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for path: PackedVector3Array in paths:
		var n := path.size()
		for i in n - 1:
			var t0 := float(i) / (n - 1)
			var t1 := float(i + 1) / (n - 1)
			var a0 := path[i] - up * width * 0.5
			var a1 := path[i] + up * width * 0.5
			var b0 := path[i + 1] - up * width * 0.5
			var b1 := path[i + 1] + up * width * 0.5
			for v in [[a0, 0.0, t0], [a1, 1.0, t0], [b1, 1.0, t1], [a0, 0.0, t0], [b1, 1.0, t1], [b0, 0.0, t1]]:
				st.set_uv(Vector2(v[1], v[2]))
				st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/wind_ribbon.gdshader")
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("intensity", intensity)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("dash", dash)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Leaves/petals spiraling up a column.
static func swirl(radius: float, height: float, color_a: Color, color_b: Color, amount := 36) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = radius
	pm.emission_ring_inner_radius = radius * 0.3
	pm.emission_ring_height = 0.5
	pm.direction = Vector3.UP
	pm.spread = 10.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3.ZERO
	pm.orbit_velocity_min = 0.15
	pm.orbit_velocity_max = 0.3
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.angular_velocity_min = -180.0
	pm.angular_velocity_max = 180.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var g := Gradient.new()
	g.set_color(0, color_a)
	g.set_color(1, color_b)
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_initial_ramp = gt
	pm.color_ramp = _fade_ramp(1.0)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.draw_pass_1 = q
	p.amount = amount
	p.lifetime = height / 7.5
	p.preprocess = p.lifetime
	p.visibility_aabb = AABB(Vector3(-radius - 4, -2, -radius - 4), Vector3(radius * 2 + 8, height + 6, radius * 2 + 8))
	return p


## Rune ring + drifting motes + soft light under a floating platform.
static func underglow(color: Color, radius := 1.8) -> Node3D:
	var n := Node3D.new()
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = radius * 0.8
	t.outer_radius = radius * 0.88
	t.rings = 40
	t.ring_segments = 4
	ring.mesh = t
	ring.position.y = -0.45
	ring.scale = Vector3(1, 0.3, 1)
	ring.material_override = ElUtil.glow_mat(color, 2.2)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	var l := OmniLight3D.new()
	l.light_color = color
	l.omni_range = 4.5
	l.light_energy = 0.9
	l.position.y = -0.8
	n.add_child(l)
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = radius * 0.85
	pm.emission_ring_inner_radius = radius * 0.6
	pm.emission_ring_height = 0.1
	pm.direction = Vector3.DOWN
	pm.spread = 15.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3.ZERO
	pm.color_ramp = _fade_ramp(1.0)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	q.material = _additive(color, BaseMaterial3D.BILLBOARD_PARTICLES)
	p.draw_pass_1 = q
	p.amount = 18
	p.lifetime = 1.8
	p.position.y = -0.5
	p.local_coords = false
	n.add_child(p)
	return n


## Distinct "ridable stone" material in a type color (ferry gold, elevator cyan, carousel lavender).
static func platform_mat(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/platform.gdshader")
	m.set_shader_parameter("glow_color", color)
	return m


## Gentle snowfall (follows the player).
static func snow(amount: int) -> GPUParticles3D:
	var p := rain(amount)
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0.2, -1, 0.1)
	pm.spread = 20.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position.y = 16.0
	var q := p.draw_pass_1 as QuadMesh
	q.size = Vector2(0.09, 0.09)
	q.material = _additive(Color(1, 1, 1, 0.8), BaseMaterial3D.BILLBOARD_PARTICLES)
	return p


## Wind-blown sand streaks (follows the player).
static func sand(amount: int) -> GPUParticles3D:
	var p := rain(amount)
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_box_extents = Vector3(30, 10, 30)
	pm.direction = Vector3(1, -0.05, 0.3)
	pm.spread = 8.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 14.0
	p.lifetime = 3.0
	p.preprocess = 3.0
	p.position.y = 2.0
	var q := p.draw_pass_1 as QuadMesh
	q.size = Vector2(0.6, 0.03)
	var m := _additive(Color(1.0, 0.85, 0.6, 0.35), BaseMaterial3D.BILLBOARD_ENABLED)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	q.material = m
	return p
