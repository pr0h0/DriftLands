class_name Constellation
extends Node3D
## A star pattern shaped like an arrow, hung in the night sky above the horizon in the direction
## of the level's secret islet. Fades in after dark (and flashes with lightning).

var azimuth := 0.0  # radians, direction to point at (atan2(x, z) of the target from the start)
var _stars: MultiMeshInstance3D
var _lines: MeshInstance3D
var _mats: Array[StandardMaterial3D] = []
const DIST := 900.0
## Arrow pointing down at the horizon: (horizontal deg, elevation deg).
const STARS := [[0, 30], [0, 24], [0.6, 18], [0, 12], [-4.5, 16.5], [4.5, 16.5], [0, 8.5], [-7, 27], [6, 29], [2.5, 34]]
const LINES := [[0, 1], [1, 2], [2, 3], [3, 6], [4, 6], [5, 6], [4, 3], [5, 3]]


func _dir(h_deg: float, e_deg: float) -> Vector3:
	var az := azimuth + deg_to_rad(h_deg)
	var el := deg_to_rad(e_deg)
	return Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))


func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	mm.mesh = q
	mm.instance_count = STARS.size()
	for i in STARS.size():
		var s: float = 14.0 if i < 7 else 8.0
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), _dir(STARS[i][0], STARS[i][1]) * DIST))
	_stars = MultiMeshInstance3D.new()
	_stars.multimesh = mm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.disable_fog = true
	var tex := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.15, Color(1, 0.95, 0.85, 0.9))
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	sm.albedo_texture = tex
	_stars.material_override = sm
	_stars.custom_aabb = AABB(Vector3.ONE * -DIST * 1.2, Vector3.ONE * DIST * 2.4)
	add_child(_stars)
	_mats.append(sm)
	var im := ImmediateMesh.new()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lm.disable_fog = true
	im.surface_begin(Mesh.PRIMITIVE_LINES, lm)
	for l in LINES:
		im.surface_add_vertex(_dir(STARS[l[0]][0], STARS[l[0]][1]) * DIST)
		im.surface_add_vertex(_dir(STARS[l[1]][0], STARS[l[1]][1]) * DIST)
	im.surface_end()
	_lines = MeshInstance3D.new()
	_lines.mesh = im
	_lines.custom_aabb = _stars.custom_aabb
	add_child(_lines)
	_mats.append(lm)


func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = cam.global_position
	var s := ElUtil.session(self)
	var cycle: SkyCycle = s.cycle if s else null
	if cycle == null:
		var t := get_tree().get_first_node_in_group("title_cycle")
		cycle = t as SkyCycle
	var a := 0.0
	if cycle:
		a = clamp((1.0 - cycle.daylight()) * 1.6 - 0.4, 0.0, 1.0)
		a = max(a, cycle.flash * 0.8) * (1.0 - cycle.storm * 0.7 + cycle.flash * 0.7)
	visible = a > 0.01
	_mats[0].albedo_color = Color(1, 0.95, 0.85, a)
	_mats[1].albedo_color = Color(0.75, 0.85, 1.0, a * 0.25)
	if s and a > 0.6:
		s.first_hint("constellation", "A constellation points toward the horizon… is something hidden that way?")
