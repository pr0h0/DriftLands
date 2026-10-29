class_name Prism
extends Node3D
## Splits a light beam: one part continues straight, one turns 90° to the left.

func _ready() -> void:
	add_child(Assets.spawn("beam_pedestal", true, 2))
	var crystal := Assets.spawn("shard", false)
	crystal.position.y = BeamEmitter.HEIGHT
	crystal.scale = Vector3(1.4, 0.8, 1.4)
	add_child(crystal)
	var m := ElUtil.unique_mat(crystal, "crystal") as StandardMaterial3D
	m.emission = Color(1.0, 0.75, 0.95)
	var body := StaticBody3D.new()
	body.collision_layer = 16
	body.set_meta("prism", self)
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.8
	cs.shape = s
	cs.position.y = BeamEmitter.HEIGHT
	body.add_child(cs)
	add_child(body)
