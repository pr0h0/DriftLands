class_name Mirror
extends Node3D
## Rotatable mirror for light-beam puzzles. Interact to turn it 45°.

var step := 0
var _frame: Node3D


func _ready() -> void:
	add_to_group("interactable")
	var model := Assets.spawn("mirror", true, 2)
	add_child(model)
	_frame = Assets.find(model, "MirrorFrame") as Node3D
	var body := StaticBody3D.new()
	body.collision_layer = 16 | 2
	body.set_meta("mirror", true)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.6, 0.12)
	cs.shape = box
	cs.position.y = 1.45
	body.add_child(cs)
	_frame.add_child(body)
	_frame.rotation.y = step * PI / 4.0


func interact_prompt() -> String:
	return "Turn mirror"


func interact() -> void:
	step += 1
	create_tween().tween_property(_frame, "rotation:y", step * PI / 4.0, 0.35).set_trans(Tween.TRANS_BACK)
	Sound.play_at("mirror", global_position)
