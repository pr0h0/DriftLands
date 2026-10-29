class_name OrbitPlatform
extends AnimatableBody3D
## A stone circling a center point (carousels). Time your jump on and off.

var center := Vector3.ZERO
var radius := 12.0
var period := 22.0
var phase := 0.0
var _t := 0.0


func _ready() -> void:
	collision_layer = 2
	sync_to_physics = true
	var model := Assets.spawn("slab", false)
	add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var cs := CollisionShape3D.new()
		cs.shape = (mi as MeshInstance3D).mesh.create_trimesh_shape()
		cs.transform = (mi as Node3D).transform
		add_child(cs)
	add_child(FX.underglow(Color(0.75, 0.6, 1.0)))
	var pm := FX.platform_mat(Color(0.75, 0.6, 1.0))
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = pm
	global_position = _pos()


func _pos() -> Vector3:
	var a := phase + _t / period * TAU
	return center + Vector3(cos(a), 0, sin(a)) * radius


func _physics_process(dt: float) -> void:
	_t += dt
	global_position = _pos()
