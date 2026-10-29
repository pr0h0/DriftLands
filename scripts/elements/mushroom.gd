class_name Mushroom
extends Area3D
## Bounce cap: land on it to spring up. Hitting it faster (diving) bounces you higher.

const MIN_BOUNCE := 16.0
const MAX_BOUNCE := 26.0
var _model: Node3D
var _cool := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.3
	cyl.height = 0.9
	cs.shape = cyl
	cs.position.y = 1.35
	add_child(cs)
	_model = Assets.spawn("mushroom", false)
	add_child(_model)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	var bcs := CollisionShape3D.new()
	var stem := CylinderShape3D.new()
	stem.radius = 0.3
	stem.height = 0.9
	bcs.shape = stem
	bcs.position.y = 0.45
	body.add_child(bcs)
	add_child(body)
	body_entered.connect(_on_body)


func _process(dt: float) -> void:
	_cool -= dt


# A jump enters the zone while still rising, so keep checking until the player starts falling.
func _physics_process(_dt: float) -> void:
	if _cool > 0.0:
		return
	for b in get_overlapping_bodies():
		if b is Player:
			_on_body(b)


func _on_body(b: Node3D) -> void:
	if not b is Player or _cool > 0.0 or b.velocity.y > 1.0:
		return
	_cool = 0.3
	var impact: float = max(0.0, -b.velocity.y)
	b.launch(clamp(impact * 1.1 + 9.0, MIN_BOUNCE, MAX_BOUNCE))
	Sound.play("bounce", -3.0, randf_range(0.95, 1.1))
	_model.scale = Vector3(1.25, 0.6, 1.25)
	create_tween().tween_property(_model, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	ElUtil.hint(self, "mushroom", "Bounce caps spring you upward. Dive onto them to bounce higher.")
