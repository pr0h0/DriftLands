class_name ShardCage
extends StaticBody3D
## Seals a shard until every linked switch is on (latches open). Glowing threads show the links.

var shard: Node3D  # a Shard or a Fragment
var switches: Array = []
var opened := false
var _mat: ShaderMaterial
var _threads: Array[MeshInstance3D] = []
var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 2
	_shape = CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.6
	_shape.shape = s
	add_child(_shape)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.6
	sm.height = 3.2
	mi.mesh = sm
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/cage.gdshader")
	_mat.set_shader_parameter("dissolve", 0.0)
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if shard is Shard:
		shard.locked = true
	else:
		shard.monitoring = false
	for sw in switches:
		sw.changed.connect(_check)
		var th := ElUtil.line(global_position, (sw as Node3D).global_position + Vector3.UP * 0.6, Color(1, 0.75, 0.4), 0.03)
		th.top_level = true
		add_child(th)
		th.global_transform = th.transform
		_threads.append(th)
	_check()


func _check() -> void:
	if opened:
		return
	var all := true
	for i in switches.size():
		var on: bool = switches[i].is_on()
		(_threads[i].material_override as StandardMaterial3D).albedo_color = Color(1, 0.8, 0.45) * (2.5 if on else 0.35)
		all = all and on
	if all:
		_open()


func _open() -> void:
	opened = true
	if shard is Shard:
		shard.locked = false
	elif is_instance_valid(shard):
		shard.set_deferred("monitoring", true)
	_shape.set_deferred("disabled", true)
	Sound.play_at("cage_open", global_position)
	var t := create_tween()
	t.tween_property(_mat, "shader_parameter/dissolve", 1.0, 1.6)
	for th in _threads:
		t.parallel().tween_property(th, "scale", Vector3(0.01, 1, 0.01), 1.6)
	t.tween_callback(queue_free)
	ElUtil.hint(self, "cage_%d" % get_instance_id(), "The seal breaks.")
