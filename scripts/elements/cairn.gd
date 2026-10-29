class_name Cairn
extends Area3D
## Checkpoint: touch it and you'll return here after a defeat.

var _active := false
var _rune: StandardMaterial3D
var _light: OmniLight3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 2.2
	cs.shape = s
	cs.position.y = 1.0
	add_child(cs)
	var model := Assets.spawn("cairn", true, 2)
	add_child(model)
	_rune = ElUtil.unique_mat(model, "rune") as StandardMaterial3D
	_rune.emission_energy_multiplier = 0.3
	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.88, 1.0)
	_light.position.y = 2.0
	_light.light_energy = 0.0
	add_child(_light)
	body_entered.connect(_on_body)


func _on_body(b: Node3D) -> void:
	if _active or not b is Player:
		return
	_active = true
	var s := ElUtil.session(self)
	if s:
		s.set_checkpoint(global_position + Vector3(0, 0.5, 1.5))
	Sound.play_at("checkpoint", global_position)
	var t := create_tween().set_parallel(true)
	t.tween_property(_rune, "emission_energy_multiplier", 5.0, 0.8)
	t.tween_property(_light, "light_energy", 2.0, 0.8)
