class_name Scarf
extends MeshInstance3D
## Verlet-chain ribbon trailing from the Wanderer's neck.

const SEGMENTS := 10
const SEG_LEN := 0.15
const ANCHOR := Vector3(0, 1.16, 0.1)

var player: Node3D  ## the body the scarf trails behind
var model: Node3D  ## the visual model it is tied to
var _pts := PackedVector3Array()
var _prev := PackedVector3Array()
var _mesh := ImmediateMesh.new()
var _t := 0.0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _mesh
	material_override = Cosmetics.scarf_material()
	extra_cull_margin = 4.0
	var a := _anchor()
	for i in SEGMENTS:
		_pts.append(a + Vector3(0, -i * SEG_LEN * 0.5, i * SEG_LEN * 0.8))
	_prev = _pts.duplicate()


func _anchor() -> Vector3:
	return model.global_transform * ANCHOR


func _physics_process(dt: float) -> void:
	_t += dt
	var dt2 := dt * dt
	_pts[0] = _anchor()
	_prev[0] = _pts[0]
	var side := model.global_basis.x
	var center := player.global_position
	for i in range(1, SEGMENTS):
		var v := (_pts[i] - _prev[i]) * 0.93
		_prev[i] = _pts[i]
		var flutter := side * sin(_t * 9.0 - i * 0.9) * 2.5 + Vector3(0, sin(_t * 6.0 - i * 1.3) * 1.5, 0)
		_pts[i] += v + (Vector3(0, -4.0, 0) + flutter * (float(i) / SEGMENTS)) * dt2
	for _it in 4:
		for i in range(1, SEGMENTS):
			var d := _pts[i] - _pts[i - 1]
			var l := d.length()
			if l > 0.0001:
				_pts[i] = _pts[i - 1] + d / l * SEG_LEN
			var local := _pts[i] - center
			var flat := Vector2(local.x, local.z)
			if local.y < 1.15 and local.y > -0.1 and flat.length() < 0.42:
				flat = flat.normalized() * 0.42 if flat.length() > 0.001 else Vector2(0, 0.42)
				_pts[i] = center + Vector3(flat.x, local.y, flat.y)


func _process(_dt: float) -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var side := model.global_basis.x
	for i in SEGMENTS:
		var t := float(i) / (SEGMENTS - 1)
		var w := 0.075 * (1.0 - t * 0.45)
		var fwd := (_pts[min(i + 1, SEGMENTS - 1)] - _pts[max(i - 1, 0)]).normalized()
		var n := side.cross(fwd).normalized()
		_mesh.surface_set_normal(n)
		_mesh.surface_set_uv(Vector2(0, t))
		_mesh.surface_add_vertex(_pts[i] - side * w)
		_mesh.surface_set_normal(n)
		_mesh.surface_set_uv(Vector2(1, t))
		_mesh.surface_add_vertex(_pts[i] + side * w)
	_mesh.surface_end()
