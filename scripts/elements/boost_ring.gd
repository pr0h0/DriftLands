class_name BoostRing
extends Area3D
## Fly through to be flung forward along the ring's axis (works in both directions).

var power := 26.0
var _cool := 0.0
var _glow: MeshInstance3D
var _pulse := 0.0
var _funnel: Area3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.6
	cyl.height = 1.8
	cs.shape = cyl
	cs.rotation.x = PI / 2
	add_child(cs)
	add_child(Assets.spawn("ring_frame", false))
	_glow = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 2.2
	t.outer_radius = 2.48
	t.rings = 48
	t.ring_segments = 8
	_glow.mesh = t
	_glow.rotation.x = PI / 2
	_glow.material_override = ElUtil.glow_mat(Color(0.55, 0.88, 1.0), 1.6)
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	var l := OmniLight3D.new()
	l.light_color = Color(0.55, 0.88, 1.0)
	l.omni_range = 7.0
	l.light_energy = 1.2
	add_child(l)
	body_entered.connect(_on_body)
	# Funnel: a wider zone either side of the ring that gently pulls gliders toward its center.
	_funnel = Area3D.new()
	_funnel.collision_layer = 0
	_funnel.collision_mask = 4
	var fcs := CollisionShape3D.new()
	var fc := CylinderShape3D.new()
	fc.radius = 6.5
	fc.height = 22.0
	fcs.shape = fc
	fcs.rotation.x = PI / 2
	_funnel.add_child(fcs)
	add_child(_funnel)


func _physics_process(dt: float) -> void:
	for b in _funnel.get_overlapping_bodies():
		if b is Player and b.gliding:
			var axis := global_basis.z
			var rel: Vector3 = b.global_position + Vector3.UP * 0.8 - global_position
			var off := rel - axis * rel.dot(axis)
			b.velocity -= off * 4.0 * dt


func _process(dt: float) -> void:
	_cool -= dt
	_pulse = move_toward(_pulse, 0.0, dt * 2.0)
	var s := 1.0 + _pulse * 0.25 + sin(Time.get_ticks_msec() * 0.003) * 0.03
	_glow.scale = Vector3(s, 1, s)


func _on_body(b: Node3D) -> void:
	if not b is Player or _cool > 0.0:
		return
	var fwd := -global_basis.z
	if b.velocity.dot(fwd) < 0.0:
		fwd = -fwd
	b.boost(fwd * power + Vector3.UP * 3.0)
	_cool = 0.6
	_pulse = 1.0
	Sound.play("boost", -2.0, randf_range(0.95, 1.05))
	ElUtil.hint(self, "ring", "Boost rings fling you forward. Chain them to cross wide gaps.")
