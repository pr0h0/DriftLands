class_name BeamEmitter
extends Node3D
## Shoots a light beam along -Z that bounces off mirrors and lights receivers.

const HEIGHT := 1.45
var _segs: Array[MeshInstance3D] = []
var _mat: ShaderMaterial


func _ready() -> void:
	add_child(Assets.spawn("beam_pedestal", true, 2))
	var crystal := Assets.spawn("shard", false)
	crystal.position.y = HEIGHT + 0.2
	crystal.scale = Vector3.ONE * 0.8
	add_child(crystal)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.85, 0.55)
	l.position.y = HEIGHT
	l.omni_range = 6.0
	add_child(l)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/beam.gdshader")
	_mat.set_shader_parameter("color", Color(1.0, 0.85, 0.55))
	_mat.set_shader_parameter("intensity", 2.2)
	_mat.set_shader_parameter("streaks", 0.4)
	for i in 16:
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.07
		c.bottom_radius = 0.07
		c.height = 1.0
		c.radial_segments = 8
		mi.mesh = c
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		mi.visible = false
		add_child(mi)
		_segs.append(mi)


func _physics_process(_dt: float) -> void:
	var space := get_world_3d().direct_space_state
	var start_dir := -global_basis.z
	start_dir.y = 0.0
	var rays := [[global_position + Vector3.UP * HEIGHT, start_dir.normalized(), null]]
	var lit := []
	var used := 0
	var split := {}
	while not rays.is_empty() and used < _segs.size():
		var r: Array = rays.pop_front()
		var origin: Vector3 = r[0]
		var dir: Vector3 = r[1]
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 80.0, 1 | 2 | 16)
		if r[2] != null:
			q.exclude = [r[2]]
		var hit := space.intersect_ray(q)
		var end: Vector3 = origin + dir * 80.0 if hit.is_empty() else hit.position
		ElUtil.place_between(_segs[used], origin, end)
		_segs[used].visible = true
		used += 1
		if hit.is_empty():
			continue
		var c: Object = hit.collider
		if c.has_meta("mirror"):
			var nd := dir.bounce((hit.normal as Vector3))
			nd.y = 0.0
			rays.append([end + nd.normalized() * 0.05, nd.normalized(), null])
		elif c.has_meta("prism") and not split.has(c):
			split[c] = true
			var center: Vector3 = (c as Node3D).global_position
			var p := Vector3(center.x, origin.y, center.z)
			var left := Vector3(dir.z, 0, -dir.x)
			rays.append([p, dir, c.get_rid()])
			rays.append([p, left, c.get_rid()])
		elif c.has_meta("receiver"):
			lit.append(c.get_meta("receiver"))
	for i in range(used, _segs.size()):
		_segs[i].visible = false
	for r in lit:
		r.mark_hit()
