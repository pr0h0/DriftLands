class_name Assets
## Instantiates generated .glb models, swaps in palette materials and builds collision.
## Node-name suffixes from Blender: "_deco" = no collision, "_invis" = collision only.

static var _scenes: Dictionary = {}
static var _shapes: Dictionary = {}


static func spawn(asset_name: String, collide := true, layer := 2, terrain := false, overrides := {}) -> Node3D:
	if not _scenes.has(asset_name):
		_scenes[asset_name] = load("res://assets/models/%s.glb" % asset_name)
	var root: Node3D = (_scenes[asset_name] as PackedScene).instantiate()
	_prepare(root, collide, layer, terrain, overrides)
	return root


static func _prepare(n: Node, collide: bool, layer: int, terrain: bool, overrides: Dictionary) -> void:
	for c in n.get_children():
		_prepare(c, collide, layer, terrain, overrides)
	var mi := n as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(i)
		if src == null:
			continue
		var key: String = overrides.get(src.resource_name, src.resource_name)
		var m := Mats.get_mat(key)
		if m:
			mi.set_surface_override_material(i, m)
	var nm := String(mi.name)
	if nm.ends_with("_invis"):
		mi.visible = false
	if collide and not nm.ends_with("_deco"):
		var body := StaticBody3D.new()
		body.collision_layer = layer
		body.collision_mask = 0
		if terrain:
			body.set_meta("terrain", true)
		var cs := CollisionShape3D.new()
		if not _shapes.has(mi.mesh):
			_shapes[mi.mesh] = mi.mesh.create_trimesh_shape()
		cs.shape = _shapes[mi.mesh]
		body.add_child(cs)
		mi.add_child(body)


## Finds a descendant by name prefix (glTF import may append suffixes).
static func find(root: Node, prefix: String) -> Node:
	for c in root.get_children():
		if String(c.name).begins_with(prefix):
			return c
		var r := find(c, prefix)
		if r:
			return r
	return null
