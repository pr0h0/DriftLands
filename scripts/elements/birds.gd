class_name Birds
extends MultiMeshInstance3D
## A small flock wheeling in lazy circles.

var center := Vector3.ZERO
var count := 10
var radius := 45.0
var _params: Array = []


func _ready() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(0, 0, -0.3), Vector3(-0.9, 0.1, 0.1), Vector3(0, 0, 0.15),
			Vector3(0, 0, -0.3), Vector3(0, 0, 0.15), Vector3(0.9, 0.1, 0.1)]:
		st.add_vertex(v)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = st.commit()
	mm.instance_count = count
	multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/bird.gdshader")
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(center - Vector3.ONE * (radius + 20), Vector3.ONE * (radius + 20) * 2)
	for i in count:
		_params.append([randf() * TAU, randf_range(0.08, 0.14), radius * randf_range(0.6, 1.1), randf_range(-6, 6), randf() * TAU])


func _process(_dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in count:
		var p: Array = _params[i]
		var a: float = p[0] + t * p[1]
		var pos := center + Vector3(cos(a) * p[2], p[3] + sin(t * 0.5 + p[4]) * 2.0, sin(a) * p[2])
		var tangent := Vector3(-sin(a), 0, cos(a))
		var basis := Basis.looking_at(tangent, Vector3.UP).rotated(tangent, -0.25)
		multimesh.set_instance_transform(i, Transform3D(basis, pos))
