class_name Sundial
extends Node3D
## Interact to swing the world between day and night.

var _cool := 0.0


func _ready() -> void:
	add_to_group("interactable")
	add_child(Assets.spawn("sundial", true, 2))


func _process(dt: float) -> void:
	_cool -= dt


func interact_prompt() -> String:
	var s := ElUtil.session(self)
	return "Turn the sundial  (→ %s)" % ("day" if s and s.cycle.is_night() else "night")


func interact() -> void:
	if _cool > 0.0:
		return
	_cool = 3.5
	var s := ElUtil.session(self)
	s.cycle.toggle_day_night(3.0)
	Sound.play_at("sundial", global_position)
