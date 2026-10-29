class_name Sentinel
extends Node3D
## Storm sentinel: a totem that charges up and lobs orbs at the player when it can see them.

const EYE_Y := 3.0
var reach := 42.0
var interval := 3.2
var _cool := 2.0
var _charge := 0.0
var _eye: StandardMaterial3D
var _light: OmniLight3D
var _halo: MeshInstance3D
var _charge_orb: MeshInstance3D
var _spin := 0.0


func _ready() -> void:
	var model := Assets.spawn("sentinel", true, 2)
	add_child(model)
	_eye = ElUtil.unique_mat(model, "eye_red") as StandardMaterial3D
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.3, 0.2)
	_light.position.y = EYE_Y
	_light.omni_range = 7.0
	add_child(_light)
	_halo = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.95
	t.outer_radius = 1.05
	t.rings = 6
	t.ring_segments = 3
	_halo.mesh = t
	_halo.position.y = EYE_Y + 1.35
	_halo.material_override = ElUtil.glow_mat(Color(1.0, 0.35, 0.2), 1.2)
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	_charge_orb = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	_charge_orb.mesh = sm
	_charge_orb.material_override = ElUtil.glow_mat(Color(1.0, 0.4, 0.2), 3.0)
	_charge_orb.top_level = true
	_charge_orb.visible = false
	add_child(_charge_orb)


func _physics_process(dt: float) -> void:
	var s := ElUtil.session(self)
	if s == null or s.player == null:
		return
	var p := s.player
	var eye := global_position + Vector3.UP * EYE_Y
	var chest := p.global_position + Vector3.UP * 0.9
	var sees := false
	if eye.distance_to(chest) < reach:
		var from := eye + (chest - eye).normalized() * 1.2
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, chest, 1 | 2))
		sees = hit.is_empty()
	_cool -= dt
	if sees and _cool <= 0.0:
		_charge += dt
		if _charge >= 1.0:
			_fire(eye, p)
			_charge = 0.0
			_cool = interval
	else:
		_charge = max(0.0, _charge - dt)
	var glow := 0.6 + _charge * 6.0
	_eye.emission_energy_multiplier = glow
	_light.light_energy = glow * 0.6
	# Halo idles slowly, spins up while charging; the orb forms in front of the eye.
	_spin = lerp(_spin, 0.6 + _charge * 9.0, 1.0 - exp(-4.0 * dt))
	_halo.rotation.y += _spin * dt
	_halo.rotation.x = sin(Time.get_ticks_msec() * 0.001) * 0.15
	_charge_orb.visible = _charge > 0.02
	if _charge_orb.visible:
		var dirp := (chest - eye).normalized()
		_charge_orb.global_position = eye + dirp * 1.1
		_charge_orb.scale = Vector3.ONE * (0.2 + _charge * 0.9) * (1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.08)


func _fire(eye: Vector3, p: Player) -> void:
	var dist := eye.distance_to(p.global_position)
	var lead := p.global_position + Vector3.UP * 0.9 + p.velocity * (dist / Orb.SPEED) * 0.6
	var orb := Orb.new()
	orb.velocity = (lead - eye).normalized() * Orb.SPEED
	get_parent().add_child(orb)
	orb.global_position = eye + orb.velocity.normalized() * 1.0
	Sound.play_at("orb_fire", eye)
	ElUtil.hint(self, "sentinel", "Sentinels fire when they see you. Break line of sight behind rocks and ruins.")


class Orb:
	extends Area3D
	const SPEED := 15.0
	var velocity := Vector3.ZERO
	var _life := 5.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 4
		var cs := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.55
		cs.shape = s
		add_child(cs)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.35
		sm.height = 0.7
		mi.mesh = sm
		mi.material_override = ElUtil.glow_mat(Color(1.0, 0.35, 0.2), 3.0)
		add_child(mi)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.35, 0.2)
		l.omni_range = 5.0
		add_child(l)
		add_child(FX.sparkles(Color(1.0, 0.4, 0.2, 1.0)))
		body_entered.connect(_on_body)

	func _physics_process(dt: float) -> void:
		_life -= dt
		var next := global_position + velocity * dt
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position, next, 1 | 2))
		if not hit.is_empty() or _life <= 0.0:
			_burst()
			return
		global_position = next

	func _on_body(b: Node3D) -> void:
		if b is Player:
			b.damage(1, global_position)
			_burst()

	func _burst() -> void:
		Sound.play_at("orb_hit", global_position, -3.0)
		set_physics_process(false)
		set_deferred("monitoring", false)
		var t := create_tween()
		t.tween_property(self, "scale", Vector3.ONE * 2.0, 0.15)
		t.tween_callback(queue_free)
