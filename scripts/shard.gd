class_name Shard
extends Area3D
## A floating light shard. Touch it to send it home to the monolith. `locked` while caged.

signal collected(shard: Shard)

var index := 0
var locked := false
var visual: Node3D
var light: OmniLight3D
var taken := false
## A heavy light orb that must be carried to the beacon by hand instead of flying home.
var carry := false:
	set(v):
		carry = v
		if is_node_ready():
			_style()
var delivered := false
var home_pos := Vector3.ZERO
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
	_style()


func _style() -> void:
	if not carry:
		return
	light.light_color = Color(1.0, 0.8, 0.45)
	light.light_energy = 3.5
	var halo := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.75
	t.outer_radius = 0.82
	halo.mesh = t
	halo.material_override = ElUtil.glow_mat(Color(1.0, 0.78, 0.4), 3.0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(halo)
	add_child(FX.sparkles(Color(1.0, 0.85, 0.5, 1.0)))


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
