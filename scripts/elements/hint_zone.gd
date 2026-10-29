class_name HintZone
extends Area3D
## Shows a one-time hint when the player walks into it.

var key := ""
var text := ""
var radius := 5.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = radius
	cs.shape = s
	add_child(cs)
	body_entered.connect(func(b): if b is Player: ElUtil.hint(self, key, text))
