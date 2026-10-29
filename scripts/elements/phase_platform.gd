class_name PhasePlatform
extends Node3D
## Exists only by night ("night") or only by day ("day").

var phase := "night"  # "night", "day", or "switch" (present while all `switches` are on)
var switches: Array = []
var present := false  # used by "manual" mode (echo stones)
var _mat: ShaderMaterial
var _body: StaticBody3D
var _presence := -1.0


func _ready() -> void:
	var model := Assets.spawn("slab", true, 2)
	add_child(model)
	_body = model.find_children("*", "StaticBody3D", true, false)[0]
	_body.set_meta("unsafe", true)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/phase.gdshader")
	if phase == "manual":
		_mat.set_shader_parameter("base_color", Color(0.6, 0.8, 0.7))
		_mat.set_shader_parameter("glow_color", Color(0.55, 1.0, 0.75))
	elif phase == "switch":
		_mat.set_shader_parameter("base_color", Color(0.75, 0.7, 0.6))
		_mat.set_shader_parameter("glow_color", Color(1.0, 0.8, 0.45))
	elif phase == "night":
		_mat.set_shader_parameter("base_color", Color(0.45, 0.5, 0.7))
		_mat.set_shader_parameter("glow_color", Color(0.45, 0.8, 1.0))
	else:
		_mat.set_shader_parameter("base_color", Color(0.85, 0.72, 0.5))
		_mat.set_shader_parameter("glow_color", Color(1.0, 0.75, 0.35))
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = _mat


func _process(dt: float) -> void:
	var want := 0.0
	if phase == "manual":
		want = 1.0 if present else 0.0
	elif phase == "switch":
		want = 1.0 if switches.all(func(sw): return sw.is_on()) else 0.0
	else:
		var s := ElUtil.session(self)
		if s == null:
			return
		want = 1.0 if s.cycle.is_night() == (phase == "night") else 0.0
	_presence = want if _presence < 0.0 else move_toward(_presence, want, dt * (3.0 if phase == "manual" else 1.2))
	_mat.set_shader_parameter("presence", _presence)
	_body.collision_layer = 2 if _presence > 0.5 else 0
