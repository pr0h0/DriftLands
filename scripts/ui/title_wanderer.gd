class_name TitleWanderer
extends CharacterBody3D
## The Wanderer pottering around the title island: strolls between spots, hops, does little
## glider hops, and stops to look around. `posing` makes it stand still facing the camera.

const WALK := 2.6
const GRAVITY := 18.0

var center := Vector3.ZERO
var radius := 15.0
var posing := false
var face_target := Vector3.ZERO

var model: Node3D
var glider: Node3D
var scarf: Scarf
var _body: Node3D
var _target := Vector3.ZERO
var _idle := 1.5
var _stuck := 0.0
var _last_pos := Vector3.ZERO
var _gliding := false
var _glide_amount := 0.0
var _anim_t := 0.0
var _yaw := 0.0
var _look_t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.5
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.75
	add_child(cs)
	model = Node3D.new()
	add_child(model)
	glider = Assets.spawn("glider", false)
	glider.position = Vector3(0, 1.95, 0)
	glider.rotation.x = 0.3
	glider.visible = false
	model.add_child(glider)
	redress()
	scarf = Scarf.new()
	scarf.player = self
	scarf.model = model
	add_child(scarf)
	_last_pos = global_position


## Rebuilds the model from the current wardrobe (or the given preview ids).
func redress(mask := "", scarf_id := "", robe := "") -> void:
	if _body:
		_body.queue_free()
	var asset := Cosmetics.mask_asset()
	if mask != "":
		for e in Cosmetics.MASKS:
			if e["id"] == mask:
				asset = e["asset"]
	_body = Assets.spawn(asset, false)
	Cosmetics.dress(_body, robe)
	model.add_child(_body)
	if scarf:
		scarf.material_override = Cosmetics.scarf_material(scarf_id)


func _pick_target() -> void:
	var space := get_world_3d().direct_space_state
	for k in 12:
		var a := randf() * TAU
		var d := randf_range(3.0, radius)
		var p := center + Vector3(cos(a) * d, 0, sin(a) * d)
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 20.0, p + Vector3.DOWN * 20.0, 1 | 2)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and hit.collider.has_meta("terrain") and (hit.normal as Vector3).y > 0.85:
			_target = hit.position
			return
	_target = center


func _physics_process(dt: float) -> void:
	var on_floor := is_on_floor()
	var hv := Vector3.ZERO
	if posing:
		_gliding = false
		var to := face_target - global_position
		_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), 1.0 - exp(-6.0 * dt))
	elif _idle > 0.0:
		_idle -= dt
		_look_t += dt
		_yaw += sin(_look_t * 1.3) * dt * 0.6
		if _idle <= 0.0:
			_pick_target()
			_stuck = 0.0
	else:
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.8:
			_idle = randf_range(1.5, 4.0)
			if randf() < 0.35 and on_floor:
				_jump(randf() < 0.5)
		else:
			hv = to.normalized() * WALK
			_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * dt))
			if on_floor and not _ground_ahead(to.normalized()):
				_idle = 1.0
				hv = Vector3.ZERO
			elif on_floor and randf() < dt * 0.15:
				_jump(randf() < 0.4)
		_stuck += dt
		if _stuck > 1.2:
			if global_position.distance_to(_last_pos) < 0.5:
				if on_floor:
					_jump(false)
				_pick_target()
			_last_pos = global_position
			_stuck = 0.0
	velocity.x = hv.x
	velocity.z = hv.z
	if on_floor:
		_gliding = false
	elif _gliding:
		velocity.y = move_toward(velocity.y, -2.2, 22.0 * dt)
	else:
		velocity.y -= GRAVITY * dt
		if velocity.y < -1.0 and has_meta("will_glide"):
			remove_meta("will_glide")
			_gliding = true
	move_and_slide()
	if global_position.y < center.y - 12.0:
		global_position = center + Vector3(0, 1.0, 4.0)
		velocity = Vector3.ZERO
	_animate(dt, on_floor, hv.length())


func _jump(glide: bool) -> void:
	velocity.y = 6.8 if not glide else 8.0
	if glide:
		set_meta("will_glide", true)
	model.scale = Vector3(0.9, 1.12, 0.9)
	create_tween().tween_property(model, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _ground_ahead(dir: Vector3) -> bool:
	var p := global_position + dir * 1.2
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p + Vector3.DOWN * 2.5, 1 | 2)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _animate(dt: float, on_floor: bool, spd: float) -> void:
	model.rotation.y = _yaw
	_anim_t += dt * (2.0 + spd * 1.6)
	var bob := absf(sin(_anim_t)) * 0.05 if on_floor and spd > 0.5 else 0.0
	model.position.y = lerp(model.position.y, bob, 1.0 - exp(-20.0 * dt))
	model.rotation.x = lerp(model.rotation.x, -0.3 if _gliding else (-0.1 if spd > 0.5 else 0.0), 1.0 - exp(-8.0 * dt))
	_glide_amount = move_toward(_glide_amount, 1.0 if _gliding else 0.0, dt * 4.0)
	glider.visible = _glide_amount > 0.01
	glider.scale = Vector3.ONE * max(0.01, smoothstep(0.0, 1.0, _glide_amount))
