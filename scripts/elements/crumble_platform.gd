class_name CrumblePlatform
extends Node3D
## Shakes when stood on, falls away, then reforms a few seconds later.

enum { SOLID, SHAKING, GONE }
var mat := "crumble"
var _state := SOLID
var _t := 0.0
var _model: Node3D
var _body: StaticBody3D


func _ready() -> void:
	_model = Assets.spawn("slab", true, 2, false, {"stone": mat})
	add_child(_model)
	_body = _model.find_children("*", "StaticBody3D", true, false)[0]
	_body.set_meta("unsafe", true)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 4
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 1.0, 4.0)
	cs.shape = box
	cs.position.y = 0.5
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_body)


func _on_body(b: Node3D) -> void:
	if b is Player and _state == SOLID:
		_state = SHAKING
		_t = 1.6
		Sound.play_at("crumble", global_position, -6.0, 1.4)
		ElUtil.hint(self, "crumble", "Cracked stone won't hold you for long. Keep moving!")


func _process(dt: float) -> void:
	_t -= dt
	match _state:
		SHAKING:
			_model.position = Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)) * 0.06
			if _t <= 0.0:
				_state = GONE
				_t = 4.0
				_body.collision_layer = 0
				Sound.play_at("crumble", global_position)
				var tw := create_tween().set_parallel(true)
				tw.tween_property(_model, "position:y", -30.0, 1.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				tw.tween_property(_model, "scale", Vector3.ONE * 0.5, 1.4)
		GONE:
			if _t <= 0.0:
				_state = SOLID
				_model.position = Vector3.ZERO
				_model.scale = Vector3.ONE * 0.01
				_body.collision_layer = 2
				create_tween().tween_property(_model, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK)
