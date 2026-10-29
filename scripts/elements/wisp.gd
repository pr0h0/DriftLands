class_name Wisp
extends Node3D
## Gloom wisp: a knot of darkness left behind when a beacon fades. Drifts around its home,
## chases light (the player), winds up and lunges when close. Night-only wisps sleep by day.

enum { PATROL, CHASE, WINDUP, LUNGE, RECOVER, SLEEP }

const CALM_EYES := Color(0.85, 0.75, 1.0)
const ANGRY_EYES := Color(1.0, 0.25, 0.6)
const TENDRILS := 5
const SEGS := 7

var home: Vector3
var radius := 6.0
var night_only := false
var speed := 5.8
var detect := 13.0
var leash := 32.0
var _state := PATROL
var _ang := randf() * TAU
var _t := 0.0
var _state_t := 0.0
var _vel := Vector3.ZERO
var _lunge_dir := Vector3.ZERO
var _agitation := 0.0
var _body: MeshInstance3D
var _mat: ShaderMaterial
var _eyes: Array[MeshInstance3D] = []
var _eye_mat: StandardMaterial3D
var _light: OmniLight3D
var _smoke: GPUParticles3D
var _tendril_mesh := ImmediateMesh.new()
var _tendril_node: MeshInstance3D
var _pts: Array = []  # per tendril: PackedVector3Array
var _prev: Array = []


func _ready() -> void:
	global_position = home
	_body = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 0.9
	s.radial_segments = 24
	s.rings = 12
	_body.mesh = s
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/wisp.gdshader")
	_body.material_override = _mat
	add_child(_body)

	_eye_mat = StandardMaterial3D.new()
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_mat.albedo_color = CALM_EYES
	_eye_mat.emission_enabled = true
	_eye_mat.emission = CALM_EYES
	_eye_mat.emission_energy_multiplier = 3.0
	for x in [-0.15, 0.15]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.075
		es.height = 0.15
		eye.mesh = es
		eye.material_override = _eye_mat
		eye.position = Vector3(x * 0.9, 0.08, -0.46)
		eye.rotation.z = -0.4 if x < 0 else 0.4
		_body.add_child(eye)
		_eyes.append(eye)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.6, 0.3, 1.0)
	_light.omni_range = 6.0
	_light.light_energy = 1.5
	add_child(_light)

	_smoke = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.gravity = Vector3(0, 0.3, 0)
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var g := Gradient.new()
	g.set_color(0, Color(0.2, 0.05, 0.3, 0.0))
	g.set_color(1, Color(0.05, 0.0, 0.1, 0.0))
	g.add_point(0.2, Color(0.25, 0.08, 0.4, 0.55))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_smoke.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.45)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	var tex := GradientTexture2D.new()
	var rg := Gradient.new()
	rg.set_color(0, Color(1, 1, 1, 1))
	rg.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = rg
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	qm.albedo_texture = tex
	q.material = qm
	_smoke.draw_pass_1 = q
	_smoke.amount = 40
	_smoke.lifetime = 1.4
	_smoke.local_coords = false
	add_child(_smoke)

	_tendril_node = MeshInstance3D.new()
	_tendril_node.mesh = _tendril_mesh
	_tendril_node.top_level = true
	_tendril_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tendril_node.extra_cull_margin = 4.0
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	tm.vertex_color_use_as_albedo = true
	_tendril_node.material_override = tm
	add_child(_tendril_node)
	_tendril_node.global_transform = Transform3D.IDENTITY
	for i in TENDRILS:
		var p := PackedVector3Array()
		for k in SEGS:
			p.append(home)
		_pts.append(p)
		_prev.append(p.duplicate())


func _set_state(s: int) -> void:
	_state = s
	_state_t = 0.0


func _physics_process(dt: float) -> void:
	var s := ElUtil.session(self)
	if s == null or s.player == null:
		_animate(dt, 0.0)
		return
	_t += dt
	_state_t += dt
	var p := s.player
	var chest := p.global_position + Vector3.UP * 1.0
	var dist := global_position.distance_to(chest)
	if night_only and not s.cycle.is_night():
		if _state != SLEEP:
			_set_state(SLEEP)
	elif _state == SLEEP:
		_set_state(PATROL)
	var target := global_position
	var spd := 2.5
	match _state:
		SLEEP, PATROL:
			_ang += dt * (0.25 if _state == SLEEP else 0.45)
			target = home + Vector3(cos(_ang) * radius, sin(_t * 1.3) * 0.8, sin(_ang) * radius)
			spd = 1.5 if _state == SLEEP else 2.5
			if _state == PATROL and dist < detect and p.global_position.distance_to(home) < leash:
				_set_state(CHASE)
				Sound.play_at("wisp_alert", global_position)
				ElUtil.hint(self, "wisp", "Gloom wisps swell before they lunge. Raise your shield, or dodge!")
		CHASE:
			target = chest
			spd = speed
			if dist > detect * 1.9 or p.global_position.distance_to(home) > leash:
				_set_state(PATROL)
			elif dist < 3.4:
				_set_state(WINDUP)
				Sound.play_at("wisp_alert", global_position, 2.0, 1.4)
		WINDUP:
			target = global_position - (chest - global_position).normalized() * 0.5
			spd = 1.0
			if _state_t > 0.5:
				_lunge_dir = (chest - global_position).normalized()
				_set_state(LUNGE)
		LUNGE:
			_vel = _lunge_dir * 14.0
			global_position += _vel * dt
			if dist < 1.1:
				p.damage(1, global_position)
				_set_state(RECOVER)
			elif _state_t > 0.35:
				_set_state(RECOVER)
		RECOVER:
			target = global_position + (global_position - chest).normalized() * 4.0 + Vector3.UP * 2.0
			spd = 4.0
			if _state_t > 1.8:
				_set_state(CHASE if dist < detect else PATROL)
	if _state != LUNGE:
		_vel = _vel.move_toward((target - global_position).limit_length(1.0) * spd, dt * 12.0)
		global_position += _vel * dt
	# Watch the player when they're near (a warning before the chase), otherwise face travel.
	var watching := _state == PATROL and dist < detect * 1.7
	var face := (chest - global_position) if (_state in [CHASE, WINDUP, LUNGE] or watching) else _vel
	if face.length() > 0.1:
		look_at(global_position + face, Vector3.UP)
	var want := 1.0 if _state in [CHASE, WINDUP, LUNGE] else 0.0
	_animate(dt, want)


func _animate(dt: float, want_agitation: float) -> void:
	_agitation = move_toward(_agitation, want_agitation, dt * 3.0)
	var sleeping := _state == SLEEP
	var a := 0.35 if sleeping else 1.0
	_mat.set_shader_parameter("alpha", a)
	_mat.set_shader_parameter("agitation", _agitation)
	_mat.set_shader_parameter("rim_color", Color(0.65, 0.35, 1.0).lerp(Color(0.95, 0.25, 0.75), _agitation))
	# Body pulse; swell during wind-up.
	var swell := 1.0 + sin(_t * 3.0) * 0.05
	if _state == WINDUP:
		swell = 1.0 + _state_t * 0.9 + sin(_state_t * 40.0) * 0.04
	elif _state == LUNGE:
		swell = 0.85
	_body.scale = _body.scale.lerp(Vector3.ONE * swell, 1.0 - exp(-14.0 * dt))
	# Eyes: open and calm, narrowed and hot, or shut while asleep.
	var eye_h := 0.08 if sleeping else (0.28 if _agitation > 0.5 else 0.5)
	for e in _eyes:
		e.scale = e.scale.lerp(Vector3(1.5, eye_h, 0.6), 1.0 - exp(-10.0 * dt))
	var ec := CALM_EYES.lerp(ANGRY_EYES, _agitation)
	_eye_mat.albedo_color = ec
	_eye_mat.emission = ec
	_eye_mat.emission_energy_multiplier = 2.0 if sleeping else 6.0 + _agitation * 4.0
	_light.light_color = Color(0.6, 0.3, 1.0).lerp(Color(1.0, 0.25, 0.6), _agitation)
	_light.light_energy = (1.2 + _agitation * 1.8) * a
	_smoke.amount_ratio = 0.3 if sleeping else 1.0
	_update_tendrils(dt, a)


func _update_tendrils(dt: float, a: float) -> void:
	var back := global_basis.z
	var dt2 := dt * dt
	for i in TENDRILS:
		var ang := float(i) / TENDRILS * TAU
		var anchor := global_transform * (Vector3(cos(ang), sin(ang), 0.0) * 0.28 + Vector3(0, 0, 0.25))
		var p: PackedVector3Array = _pts[i]
		var pv: PackedVector3Array = _prev[i]
		p[0] = anchor
		pv[0] = anchor
		for k in range(1, SEGS):
			var v := (p[k] - pv[k]) * 0.9
			pv[k] = p[k]
			var wob := Vector3(sin(_t * 5.0 + k + i * 1.7), cos(_t * 4.0 + k * 1.3 + i), 0) * 1.5
			p[k] += v + (back * 3.0 + wob + Vector3.UP * 0.5) * dt2
		for k in range(1, SEGS):
			var d := p[k] - p[k - 1]
			var l := d.length()
			if l > 0.0001:
				p[k] = p[k - 1] + d / l * 0.16
		_pts[i] = p
		_prev[i] = pv
	_tendril_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for i in TENDRILS:
		var p: PackedVector3Array = _pts[i]
		_tendril_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for k in SEGS:
			var t := float(k) / (SEGS - 1)
			var dir := (p[min(k + 1, SEGS - 1)] - p[max(k - 1, 0)]).normalized()
			var side := dir.cross(cam.global_position - p[k]).normalized()
			var w := 0.09 * (1.0 - t)
			var c := Color(0.06, 0.0, 0.12).lerp(Color(0.6, 0.3, 1.0).lerp(Color(1.0, 0.3, 0.7), _agitation), t * 0.6)
			c.a = (1.0 - t) * 0.85 * a
			_tendril_mesh.surface_set_color(c)
			_tendril_mesh.surface_add_vertex(p[k] - side * w)
			_tendril_mesh.surface_set_color(c)
			_tendril_mesh.surface_add_vertex(p[k] + side * w)
		_tendril_mesh.surface_end()
