class_name GateCourse
extends Node3D
## Fly through the golden start gate, then every lit gate in order before time runs out.

signal changed

var points: Array[Vector3] = []
var time_limit := 30.0
var solved := false
var _gates: Array[Area3D] = []
var _mats: Array[StandardMaterial3D] = []
var _next := 0
var _timer := 0.0
var _running := false


func is_on() -> bool:
	return solved


## Cancels an in-progress run (e.g. when the player returns to safe ground).
func reset_run() -> void:
	if _running:
		_running = false
		get_tree().call_group("hud", "clear_timer")
		_refresh()


func _ready() -> void:
	add_to_group("gate_course")
	for i in points.size():
		var a := points[max(i - 1, 0)]
		var b := points[min(i + 1, points.size() - 1)]
		var g := Area3D.new()
		g.collision_layer = 0
		g.collision_mask = 4
		g.transform = Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), points[i])
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 2.3
		cyl.height = 2.0
		cs.shape = cyl
		cs.rotation.x = PI / 2
		g.add_child(cs)
		var mi := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 2.0
		t.outer_radius = 2.25
		t.rings = 40
		t.ring_segments = 6
		mi.mesh = t
		mi.rotation.x = PI / 2
		var m := ElUtil.glow_mat(Color.WHITE, 1.0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mi)
		add_child(g)
		g.body_entered.connect(_on_gate.bind(i))
		_gates.append(g)
		_mats.append(m)
	_refresh()


func _refresh() -> void:
	for i in _mats.size():
		var c := Color(0.5, 0.5, 0.55) * 0.25
		if solved:
			c = Color(1.0, 0.85, 0.5) * 0.6
		elif not _running and i == 0:
			c = Color(1.0, 0.78, 0.35) * 2.0
		elif _running and i == _next:
			c = Color(0.5, 0.9, 1.0) * 2.2
		elif _running and i < _next:
			c = Color(0.5, 0.9, 1.0) * 0.35
		_mats[i].albedo_color = c


func _on_gate(body: Node3D, i: int) -> void:
	if solved or not body is Player:
		return
	if not _running and i == 0:
		_running = true
		_next = 1
		_timer = time_limit
		Sound.play("gate", -2.0)
		ElUtil.hint(self, "gates", "Fly through each glowing gate in order before time runs out!")
	elif _running and i == _next:
		_next += 1
		Sound.play("gate", -2.0, 1.0 + _next * 0.06)
		if _next >= _gates.size():
			solved = true
			_running = false
			get_tree().call_group("hud", "clear_timer")
			changed.emit()
	_refresh()


func _process(dt: float) -> void:
	if not _running:
		return
	_timer -= dt
	get_tree().call_group("hud", "set_timer", _timer)
	if _timer <= 0.0:
		_running = false
		Sound.play("gate_fail", -2.0)
		get_tree().call_group("hud", "clear_timer")
		ElUtil.hint(self, "gates_fail_%d" % Time.get_ticks_msec(), "Out of time. Return to the golden gate to try again.")
		_refresh()
