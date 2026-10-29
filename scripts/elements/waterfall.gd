class_name Waterfall
extends MeshInstance3D
## A ribbon of water spilling off an island edge into the clouds.

var top := Vector3.ZERO
var out := Vector3.RIGHT
var length := 70.0
var width := 2.2


func _ready() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var o := Vector3(out.x, 0, out.z).normalized()
	var side := o.cross(Vector3.UP).normalized()
	var rows := 28
	var pts: Array[Vector3] = []
	var ws: Array[float] = []
	for i in rows + 1:
		var s := float(i) / rows
		var d := pow(s, 1.6) * length
		pts.append(top + o * 3.5 * (1.0 - exp(-d / 5.0)) + Vector3.DOWN * d)
		ws.append(width * (1.0 + s * 1.8))
	for i in rows:
		var a0 := pts[i] - side * ws[i] * 0.5
		var a1 := pts[i] + side * ws[i] * 0.5
		var b0 := pts[i + 1] - side * ws[i + 1] * 0.5
		var b1 := pts[i + 1] + side * ws[i + 1] * 0.5
		var v0 := float(i) / rows
		var v1 := float(i + 1) / rows
		for v in [[a0, 0.0, v0], [a1, 1.0, v0], [b1, 1.0, v1], [a0, 0.0, v0], [b1, 1.0, v1], [b0, 0.0, v1]]:
			st.set_normal(o)
			st.set_uv(Vector2(v[1], v[2]))
			st.add_vertex(v[0])
	mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/water.gdshader")
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mist := FX.sparkles(Color(1, 1, 1, 0.6))
	mist.amount = 24
	mist.position = top + o * 1.5
	add_child(mist)
