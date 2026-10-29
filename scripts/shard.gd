class_name Shard
extends Area3D
## A floating light shard. Touch it to send it home to the monolith. `locked` while caged.

signal collected(shard: Shard)

var index := 0
var locked := false
var visual: Node3D
var light: OmniLight3D
var taken := false
var _t := randf() * 10.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.3
	cs.shape = s
	add_child(cs)
	visual = Assets.spawn("shard", false)
	add_child(visual)
	light = OmniLight3D.new()
	light.light_color = Color(0.55, 0.85, 1.0)
	light.light_energy = 2.5
	light.omni_range = 7.0
	add_child(light)
	add_child(FX.sparkles(Color(0.7, 0.92, 1.0, 1.0)))
	body_entered.connect(_on_body_entered)


func _process(dt: float) -> void:
	_t += dt
	visual.rotation.y += dt * 1.2
	if not taken:
		visual.position.y = sin(_t * 1.6) * 0.15
	if not taken and not locked and has_overlapping_bodies():
		for b in get_overlapping_bodies():
			_on_body_entered(b)


func _on_body_entered(body: Node3D) -> void:
	if taken or locked or not body is Player:
		return
	taken = true
	collected.emit(self)
