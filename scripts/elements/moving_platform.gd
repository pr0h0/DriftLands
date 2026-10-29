class_name MovingPlatform
extends AnimatableBody3D
## Ferries back and forth between two points, pausing at each end.

var a: Vector3
var b: Vector3
var travel := 7.0
var wait := 1.5
var asset := "slab"
var _t := 0.0


func _ready() -> void:
	collision_layer = 2
	sync_to_physics = true
	var model := Assets.spawn(asset, false)
	add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var cs := CollisionShape3D.new()
		cs.shape = (mi as MeshInstance3D).mesh.create_trimesh_shape()
		cs.transform = (mi as Node3D).transform
		add_child(cs)
	var vertical := absf(b.y - a.y) > Vector2(b.x - a.x, b.z - a.z).length()
	var col := Color(0.45, 0.9, 1.0) if vertical else Color(1.0, 0.78, 0.4)
	add_child(FX.underglow(col))
	if asset == "slab":
		var pm := FX.platform_mat(col)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = pm
	global_position = a


func _physics_process(dt: float) -> void:
	_t += dt
	var period := 2.0 * (travel + wait)
	var t := fmod(_t, period)
	var u := 0.0
	if t < wait:
		u = 0.0
	elif t < wait + travel:
		u = smoothstep(0.0, 1.0, (t - wait) / travel)
	elif t < 2.0 * wait + travel:
		u = 1.0
	else:
		u = 1.0 - smoothstep(0.0, 1.0, (t - 2.0 * wait - travel) / travel)
	global_position = a.lerp(b, u)
