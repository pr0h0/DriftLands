class_name ElUtil
## Small helpers shared by gameplay elements.


static func session(n: Node) -> Session:
	return n.get_tree().get_first_node_in_group("session") as Session


static func hint(n: Node, key: String, text: String) -> void:
	var s := session(n)
	if s:
		s.first_hint(key, text)


## Duplicates every surface using `mat_name` under `root` so it can be animated per instance.
static func unique_mat(root: Node, mat_name: String) -> Material:
	var shared := Mats.get_mat(mat_name)
	var dup := shared.duplicate()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		for i in (mi as MeshInstance3D).mesh.get_surface_count():
			if mi.get_surface_override_material(i) == shared:
				mi.set_surface_override_material(i, dup)
	return dup


static func glow_mat(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color * energy
	m.disable_receive_shadows = true
	return m


## A thin glowing line from a to b (cylinder aligned between the points).
static func line(a: Vector3, b: Vector3, color: Color, radius := 0.04) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 1.0
	c.radial_segments = 6
	c.rings = 1
	mi.mesh = c
	mi.material_override = glow_mat(color, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	place_between(mi, a, b)
	return mi


static func place_between(n: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return
	var y := d / len
	var x := y.cross(Vector3.UP if abs(y.y) < 0.99 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	n.transform = Transform3D(Basis(x, y * len, z), (a + b) * 0.5)
