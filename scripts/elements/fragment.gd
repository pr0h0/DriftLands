class_name Fragment
extends Area3D
## Optional collectible: a small mote of light tucked away somewhere hard to reach.

signal found(f: Fragment)

var index := 0
var _t := randf() * 10.0
var _core: MeshInstance3D
var _orbit: Node3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.2
	cs.shape = s
	add_child(cs)
	_core = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	_core.mesh = sm
	_core.material_override = ElUtil.glow_mat(Color(1.0, 0.85, 0.5), 4.0)
	add_child(_core)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.45)
	l.omni_range = 4.0
	l.light_energy = 1.5
	add_child(l)
	var fx := FX.sparkles(Color(1.0, 0.85, 0.5, 1.0))
	fx.amount = 16
	add_child(fx)
	_orbit = Node3D.new()
	add_child(_orbit)
	for i in 3:
		var sp := MeshInstance3D.new()
		var s2 := SphereMesh.new()
		s2.radius = 0.05
		s2.height = 0.1
		sp.mesh = s2
		sp.material_override = ElUtil.glow_mat(Color(1.0, 0.92, 0.7), 4.0)
		var a := i * TAU / 3.0
		sp.position = Vector3(cos(a) * 0.45, sin(a * 2.0) * 0.12, sin(a) * 0.45)
		_orbit.add_child(sp)
	body_entered.connect(_on_body)


func _process(dt: float) -> void:
	_t += dt
	_core.position.y = sin(_t * 2.0) * 0.12
	_core.scale = Vector3.ONE * (1.0 + sin(_t * 5.0) * 0.15)
	_orbit.rotation = Vector3(sin(_t * 0.7) * 0.5, _t * 2.4, cos(_t * 0.5) * 0.4)
	_orbit.position.y = _core.position.y


func _on_body(b: Node3D) -> void:
	if b is Player:
		Sound.play("fragment", -2.0)
		found.emit(self)
		set_deferred("monitoring", false)
		var t := create_tween()
		t.tween_property(self, "scale", Vector3.ONE * 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_callback(queue_free)
