class_name Lever
extends Node3D
## Pull to turn linked Turning structures.

var targets: Array = []
var solid := true
var _arm: Node3D
var _cool := 0.0
var _flip := false


func _ready() -> void:
	add_to_group("interactable")
	var model := Assets.spawn("lever", solid, 2)
	add_child(model)
	_arm = Assets.find(model, "LeverArm") as Node3D
	_arm.position.y = 0.55
	_arm.rotation.x = -0.6


func _process(dt: float) -> void:
	_cool -= dt


func interact_prompt() -> String:
	return "Pull the lever" if _cool <= 0.0 else "…"


func interact() -> void:
	if _cool > 0.0:
		return
	_cool = 2.6
	_flip = not _flip
	create_tween().tween_property(_arm, "rotation:x", 0.6 if _flip else -0.6, 0.35).set_trans(Tween.TRANS_BACK)
	Sound.play_at("plate_on", global_position)
	for t in targets:
		t.turn()
	ElUtil.hint(self, "lever", "Levers turn the old causeways. Watch where the path leads now.")
