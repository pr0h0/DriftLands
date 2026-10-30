class_name PressurePlate
extends Node3D
## Pressed while anything (the player or a push stone) stands on it.

signal changed

var _count := 0
var _plate: Node3D
var _rune: StandardMaterial3D


func is_on() -> bool:
	return _count > 0


func _ready() -> void:
	add_to_group("pressure_plate")
	var model := Assets.spawn("pressure_plate", true, 2)
	add_child(model)
	_plate = Assets.find(model, "Plate_deco") as Node3D
	_rune = ElUtil.unique_mat(model, "rune") as StandardMaterial3D
	_rune.emission_energy_multiplier = 0.2
	var body := StaticBody3D.new()
	body.collision_layer = 2
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.75, 0.3, 1.75)
	cs.shape = box
	body.add_child(cs)
	add_child(body)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 4 | 8
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(1.6, 1.2, 1.6)
	acs.shape = abox
	acs.position.y = 0.7
	area.add_child(acs)
	add_child(area)
	area.body_entered.connect(func(_b): _set_count(_count + 1))
	area.body_exited.connect(func(_b): _set_count(_count - 1))


func _set_count(n: int) -> void:
	var was := is_on()
	_count = max(n, 0)
	if was == is_on():
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(_plate, "position:y", -0.1 if is_on() else 0.0, 0.2)
	t.tween_property(_rune, "emission_energy_multiplier", 4.0 if is_on() else 0.2, 0.3)
	Sound.play_at("plate_on" if is_on() else "plate_off", global_position, -2.0)
	changed.emit()
	if is_on():
		ElUtil.hint(self, "plate", "Pressure plates stay down only while something rests on them. Stones can be pushed.")
