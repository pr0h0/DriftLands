class_name Turning
extends AnimatableBody3D
## A structure on a pivot (a causeway or islet) that turns by `step` degrees each time a linked
## lever is pulled. It rotates slowly so anything standing on it is carried along.

var asset := "causeway"
var step := 90.0
var turn_time := 2.4
var _target := 0.0


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
	_target = rotation.y


func turn() -> void:
	_target += deg_to_rad(step)
	Sound.play_at("mirror", global_position, 2.0, 0.6)


func is_turning() -> bool:
	return absf(angle_difference(rotation.y, _target)) > 0.001


func _physics_process(dt: float) -> void:
	var speed := deg_to_rad(step) / turn_time
	rotation.y = rotate_toward(rotation.y, _target, speed * dt)
