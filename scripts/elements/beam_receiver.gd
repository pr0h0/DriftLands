class_name BeamReceiver
extends Node3D
## Lights up while a beam touches its crystal.

signal changed

var lit := false
var _hit_frame := -100


## Called by any emitter whose beam touches this crystal this physics frame.
func mark_hit() -> void:
	_hit_frame = Engine.get_physics_frames()


func _physics_process(_dt: float) -> void:
	set_lit(Engine.get_physics_frames() - _hit_frame <= 2)
var _crystal_mat: StandardMaterial3D
var _light: OmniLight3D


func is_on() -> bool:
	return lit


func _ready() -> void:
	add_to_group("beam_receiver")
	add_child(Assets.spawn("beam_pedestal", true, 2))
	var crystal := Assets.spawn("shard", false)
	crystal.position.y = BeamEmitter.HEIGHT + 0.1
	add_child(crystal)
	_crystal_mat = ElUtil.unique_mat(crystal, "crystal") as StandardMaterial3D
	_crystal_mat.emission_energy_multiplier = 0.2
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.85, 0.55)
	_light.position.y = BeamEmitter.HEIGHT
	_light.light_energy = 0.0
	_light.omni_range = 8.0
	add_child(_light)
	var body := StaticBody3D.new()
	body.collision_layer = 16
	body.set_meta("receiver", self)
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.85
	cs.shape = s
	cs.position.y = BeamEmitter.HEIGHT
	body.add_child(cs)
	add_child(body)


func set_lit(v: bool) -> void:
	if v == lit:
		return
	lit = v
	var t := create_tween().set_parallel(true)
	t.tween_property(_crystal_mat, "emission_energy_multiplier", 6.0 if v else 0.2, 0.4)
	t.tween_property(_light, "light_energy", 3.0 if v else 0.0, 0.4)
	if v:
		Sound.play_at("gate", global_position, 0.0, 0.8)
	changed.emit()
