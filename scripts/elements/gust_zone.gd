class_name GustZone
extends Area3D
## Periodic sideways wind that shoves the player (much harder while gliding).

var size := Vector3(20, 20, 20)
var dir := Vector3.RIGHT
var strength := 9.0
var period := 7.0
var on_time := 4.0
var _t := 0.0
var _fx: GPUParticles3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)
	_fx = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = size * 0.5
	pm.direction = dir
	pm.spread = 3.0
	pm.initial_velocity_min = 18.0
	pm.initial_velocity_max = 26.0
	pm.gravity = Vector3.ZERO
	pm.color_ramp = FX._fade_ramp(0.5)
	_fx.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 0.05)
	q.material = FX._additive(Color(0.85, 0.9, 1.0, 0.45), BaseMaterial3D.BILLBOARD_ENABLED)
	_fx.draw_pass_1 = q
	_fx.amount = 90
	_fx.lifetime = 1.2
	_fx.visibility_aabb = AABB(-size, size * 2.0)
	add_child(_fx)


func _physics_process(dt: float) -> void:
	_t += dt
	var phase := fmod(_t, period)
	var active := phase < on_time
	_fx.emitting = phase < on_time - 0.3 or phase > period - 0.8
	if not active:
		return
	for b in get_overlapping_bodies():
		if b is Player:
			b.wind_push += dir * strength
			ElUtil.hint(self, "gust", "Storm gusts come in waves. Wait for a lull, or fight the wind.")
