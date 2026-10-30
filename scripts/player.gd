class_name Player
extends CharacterBody3D
## The Wanderer: walk, run, jump, a toggleable glider that rides updrafts, boost rings and
## launch pads; can be hurt by enemies, pushed by gusts, and can push stones and use things.

signal fell
signal hurt
signal died

const WALK_SPEED := 4.5
const RUN_SPEED := 7.5
const GROUND_ACCEL := 30.0
const AIR_ACCEL := 8.0
const JUMP_VELOCITY := 6.8
const GRAVITY := 18.0
const MAX_FALL := 32.0
const GLIDE_SPEED := 10.0
const DIVE_SPEED := 16.0
const GLIDE_SINK := 2.2
const DIVE_SINK := 7.0
const GLIDE_TURN := 2.2
const MOUSE_SENS := 0.0025
const MAX_HEALTH := 3

var yaw := 0.0
var pitch := -0.25
var gliding := false
var glide_heading := Vector3.FORWARD
var updrafts: Array = []
var input_enabled := true
var last_safe := Vector3.ZERO
var kill_y := -60.0
var health := MAX_HEALTH
var wind_push := Vector3.ZERO
var interact_target: Node3D
var debug_dir := Vector3.ZERO  # probe/testing: forced movement direction
var debug_block := false
var debug_dive := false
var carrying: PushStone
var holding_orb := false  ## a light orb: hands full, no shield, no running
var _carry_prompt := ""
var model_asset := ""  # empty = the wardrobe's mask

var model: Node3D
var glider: Node3D
var pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D
var scarf: Scarf
var _dust: GPUParticles3D

var _coyote := 0.0
var _jump_buffer := 0.0
var _air_time := 0.0
var _safe_timer := 0.0
var _anim_t := 0.0
var _step_phase := 0.0
var _glide_amount := 0.0
var _prev_heading_yaw := 0.0
var _boost := 0.0
var _boost_speed := 0.0
var _invuln := 0.0
var _mouse_idle := 10.0
var _fov_kick := 0.0
var _fall_speed := 0.0
var _was_on_floor := true
var _stone_floor := false
var _mantle_cool := 0.0
var falls := 0
var hits := 0
var _marker: MeshInstance3D
var _night_light: OmniLight3D
var blocking := false
var stamina := 1.0
var _stamina_wait := 0.0
var _shield: MeshInstance3D
var _shield_mat: ShaderMaterial


func _ready() -> void:
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1 | 2 | 8
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
	model.rotation.y = yaw
	var body := Assets.spawn(model_asset if model_asset != "" else Cosmetics.mask_asset(), false)
	Cosmetics.dress(body)
	model.add_child(body)
	glider = Assets.spawn("glider", false)
	glider.position = Vector3(0, 1.95, 0)
	glider.rotation.x = 0.3
	glider.visible = false
	model.add_child(glider)

	pivot = Node3D.new()
	pivot.top_level = true
	add_child(pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 4.5
	spring.collision_mask = 1 | 2
	spring.margin = 0.3
	var ss := SphereShape3D.new()
	ss.radius = 0.25
	spring.shape = ss
	spring.add_excluded_object(get_rid())
	pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = Settings.get_v("fov")
	camera.far = 3000.0
	spring.add_child(camera)
	pivot.global_position = global_position + Vector3(0, 1.5, 0)
	pivot.rotation = Vector3(pitch, yaw, 0)

	scarf = Scarf.new()
	scarf.player = self
	scarf.model = model
	add_child(scarf)
	add_child(FX.motes())
	_dust = FX.dust()
	add_child(_dust)
	_marker = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	q.orientation = PlaneMesh.FACE_Y
	_marker.mesh = q
	var mm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform float alpha = 0.6;
void fragment() {
	float d = distance(UV, vec2(0.5)) * 2.0;
	float blob = (1.0 - smoothstep(0.2, 1.0, d)) * 0.55;
	float ring = smoothstep(0.78, 0.86, d) * (1.0 - smoothstep(0.9, 0.98, d));
	ALBEDO = mix(vec3(0.05, 0.04, 0.08), vec3(1.0, 0.9, 0.7), ring);
	ALPHA = max(blob, ring * 0.9) * alpha;
}"""
	mm.shader = sh
	_marker.material_override = mm
	_marker.top_level = true
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)
	_night_light = OmniLight3D.new()
	_night_light.light_color = Color(1.0, 0.85, 0.65)
	_night_light.omni_range = 7.0
	_night_light.omni_attenuation = 1.4
	_night_light.position = Vector3(0, 1.6, 0.4)
	_night_light.shadow_enabled = false
	add_child(_night_light)
	_shield = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.05
	sm.height = 2.1
	_shield.mesh = sm
	_shield.position.y = 0.85
	_shield_mat = ShaderMaterial.new()
	_shield_mat.shader = preload("res://shaders/cage.gdshader")
	_shield_mat.set_shader_parameter("color", Color(0.55, 0.85, 1.0))
	_shield.material_override = _shield_mat
	_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shield.visible = false
	add_child(_shield)
	last_safe = global_position


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Touch.active:
		look_by(event.relative, MOUSE_SENS * float(Settings.get_v("mouse_sens")))
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not Touch.active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("respawn"):
		respawn(false)
	elif event.is_action_pressed("interact") and carrying:
		drop_carried(false)
	elif event.is_action_pressed("interact") and interact_target:
		interact_target.interact()


## Turns the camera by a mouse or touch drag (pixels × radians per pixel, sensitivity included).
func look_by(rel: Vector2, sens: float) -> void:
	yaw -= rel.x * sens
	var dy: float = rel.y * sens * (-1.0 if Settings.get_v("invert_y") else 1.0)
	pitch = clamp(pitch - dy, -1.3, 0.6)
	_mouse_idle = 0.0


func _physics_process(dt: float) -> void:
	var input := Vector2.ZERO
	_mouse_idle += dt
	if input_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var look := Vector2(Input.get_axis("look_left", "look_right"), Input.get_axis("look_up", "look_down"))
		if look.length() > 0.1:
			_mouse_idle = 0.0
		yaw -= look.x * 2.5 * dt
		pitch = clamp(pitch - look.y * 2.0 * dt * (-1.0 if Settings.get_v("invert_y") else 1.0), -1.3, 0.6)
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
	if debug_dir != Vector3.ZERO:
		dir = debug_dir
	var on_floor := is_on_floor()
	_invuln -= dt
	_mantle_cool -= dt
	_boost -= dt
	_update_block(dt)

	if on_floor:
		_coyote = 0.12
		_air_time = 0.0
		if gliding:
			set_gliding(false)
		_track_safe(dt)
	else:
		_coyote -= dt
		_air_time += dt

	if input_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer = 0.15
	else:
		_jump_buffer -= dt

	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_coyote = 0.0
		_jump_buffer = 0.0
		Sound.play("jump", -8.0, randf_range(0.95, 1.1))
		_squash(Vector3(0.9, 1.12, 0.9))
	elif _jump_buffer > 0.0 and not on_floor and _air_time > 0.12:
		set_gliding(not gliding)
		_jump_buffer = 0.0

	var draft := _strongest_updraft()
	var lift: float = draft.lift_at(global_position) if draft else 0.0
	var diving := debug_dive or (input_enabled and Input.is_action_pressed("sprint"))
	if lift > 0.0 and not on_floor and not gliding and _air_time > 0.25:
		set_gliding(true)

	if gliding and draft and lift > 0.0 and _boost <= 0.0:
		# Hover inside the column: drift with input, otherwise settle toward its center.
		# Holding dive (Shift) sinks straight down through the column instead of rising.
		if dir.length() > 0.1:
			var ang := glide_heading.signed_angle_to(dir.normalized(), Vector3.UP)
			glide_heading = glide_heading.rotated(Vector3.UP, clamp(ang, -GLIDE_TURN * 2.0 * dt, GLIDE_TURN * 2.0 * dt))
		var to_center := draft.global_position - global_position
		to_center.y = 0.0
		var target := dir * 4.0 if dir.length() > 0.1 else to_center.limit_length(3.0) * 0.8
		var hv := Vector3(velocity.x, 0, velocity.z).move_toward(target, 10.0 * dt)
		velocity.x = hv.x
		velocity.z = hv.z
		velocity.y = move_toward(velocity.y, -6.0 if diving else lift, 18.0 * dt)
	elif gliding:
		if dir.length() > 0.1:
			var ang := glide_heading.signed_angle_to(dir.normalized(), Vector3.UP)
			var turn := GLIDE_TURN * (0.5 if _boost > 0.0 else 1.0)
			glide_heading = glide_heading.rotated(Vector3.UP, clamp(ang, -turn * dt, turn * dt))
		var target_speed := DIVE_SPEED if diving else GLIDE_SPEED
		if _boost > 0.0:
			target_speed = max(target_speed, lerp(GLIDE_SPEED, _boost_speed, clamp(_boost / 1.0, 0.0, 1.0)))
		var hv := Vector3(velocity.x, 0, velocity.z)
		hv = hv.move_toward(glide_heading * target_speed, (4.0 if _boost > 0.0 else 8.0) * dt)
		velocity.x = hv.x
		velocity.z = hv.z
		var sink := DIVE_SINK if diving else GLIDE_SINK
		velocity.y = move_toward(velocity.y, -sink, (5.0 if _boost > 0.0 else 22.0) * dt)
	else:
		var speed := 2.6 if blocking else (RUN_SPEED if diving else WALK_SPEED)
		if carrying or holding_orb:
			speed = WALK_SPEED * 0.8
		var hv := Vector3(velocity.x, 0, velocity.z)
		var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
		if on_floor and _on_ice():
			accel = 3.5
			speed *= 1.25
		if _boost > 0.0:
			accel = 2.0
		hv = hv.move_toward(dir * speed, accel * dt)
		velocity.x = hv.x
		velocity.z = hv.z
		if not on_floor:
			var g := GRAVITY
			if velocity.y > 0.0 and not Input.is_action_pressed("jump") and _boost <= 0.0:
				g *= 2.2
			velocity.y = max(velocity.y - g * dt, -MAX_FALL)

	if wind_push != Vector3.ZERO:
		velocity += wind_push * dt * (1.0 if gliding else (0.25 if on_floor else 0.6))
		wind_push = Vector3.ZERO

	_fall_speed = -velocity.y
	var pre_hv := Vector3(velocity.x, 0, velocity.z)
	move_and_slide()
	_push_bodies(dir)
	_try_mantle(dir, pre_hv)
	var now_floor := is_on_floor()
	if now_floor and not _was_on_floor:
		_on_landed()
	_was_on_floor = now_floor
	if global_position.y < kill_y:
		respawn(true)
	_find_interactable()
	_update_visuals(dt, now_floor)


func _on_ice() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, global_position + Vector3.DOWN * 0.6, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider.has_meta("ice")


func pick_up(stone: PushStone) -> void:
	carrying = stone
	stone.lift(self)
	_squash(Vector3(1.1, 0.88, 1.1))


## A pressure plate just ahead that a carried stone would snap onto (null if none is free).
func _plate_target() -> Node3D:
	var ahead := global_position - model.global_basis.z.slide(Vector3.UP).normalized() * 1.25
	for plate: Node3D in get_tree().get_nodes_in_group("pressure_plate"):
		var to := plate.global_position - ahead
		if Vector2(to.x, to.z).length() < 1.9 and absf(to.y) < 1.2 \
				and Vector2(plate.global_position.x - global_position.x, plate.global_position.z - global_position.z).length() > 1.1:
			return plate
	return null


## Sets the carried stone down in front (onto a plate right ahead, if there is one), or lets
## it fall from where it is when dropped in mid-air.
func drop_carried(in_air: bool) -> void:
	var stone := carrying
	if stone == null:
		return
	carrying = null
	interact_target = null
	_carry_prompt = ""
	if in_air:
		stone.set_down(stone.global_position)
		return
	var plate := _plate_target()
	if plate:
		stone.set_down(plate.global_position + Vector3.UP * 0.17)
		return
	var fwd := -model.global_basis.z.slide(Vector3.UP).normalized()
	var space := get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(1.15, 1.1, 1.15)
	for dir in [fwd, fwd.rotated(Vector3.UP, 0.8), fwd.rotated(Vector3.UP, -0.8), fwd.rotated(Vector3.UP, PI / 2), fwd.rotated(Vector3.UP, -PI / 2), -fwd]:
		var p: Vector3 = global_position + dir * 1.25
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, p + Vector3.DOWN * 2.0, 1 | 2))
		if hit.is_empty():
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = box
		q.transform = Transform3D(Basis(), (hit.position as Vector3) + Vector3.UP * 0.62)
		q.collision_mask = 1 | 2 | 4 | 8
		q.exclude = [get_rid()]
		if space.intersect_shape(q, 1).is_empty():
			stone.set_down(hit.position + Vector3.UP * 0.02)
			return
	stone.go_home()


func _push_bodies(dir: Vector3) -> void:
	if dir.length() < 0.1 or not is_on_floor() or carrying:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var stone := c.get_collider() as PushStone
		if stone == null:
			continue
		var into := -c.get_normal()
		into.y = 0.0
		if into.normalized().dot(dir.normalized()) > 0.4:
			# Push along the dominant axis so stones line up neatly with plates.
			var d := dir.normalized()
			stone.push(Vector3(sign(d.x), 0, 0) if abs(d.x) > abs(d.z) else Vector3(0, 0, sign(d.z)))


## Ledge assist: bumping into a ledge up to chest height while airborne pulls you on top.
func _try_mantle(dir: Vector3, pre_hv: Vector3) -> void:
	if is_on_floor() or velocity.y > 3.0 or _mantle_cool > 0.0:
		return
	var toward := dir if dir.length() > 0.1 else pre_hv
	if toward.length() < 0.5:
		return
	toward = toward.normalized()
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if n.y > 0.4 or c.get_collider() is RigidBody3D:
			continue
		var into := Vector3(-n.x, 0, -n.z).normalized()
		if into.dot(toward) < 0.3:
			continue
		var probe := global_position + into * 0.6 + Vector3.UP * 1.7
		var q := PhysicsRayQueryParameters3D.create(probe, probe + Vector3.DOWN * 2.2, 1 | 2)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
			continue
		var rise: float = hit.position.y - global_position.y
		if rise < 0.15 or rise > 1.6:
			continue
		# Make sure there is head room on top.
		var top: Vector3 = hit.position + Vector3.UP * 0.05
		var space := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.3
		cap.height = 1.4
		space.shape = cap
		space.transform = Transform3D(Basis(), top + Vector3.UP * 0.75)
		space.collision_mask = 1 | 2
		space.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(space, 1).is_empty():
			continue
		set_gliding(false)
		velocity = into * 2.0
		_mantle_cool = 0.4
		var t := create_tween()
		t.tween_property(self, "global_position", top, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_squash(Vector3(0.9, 1.1, 0.9))
		Sound.play("land", -12.0, 1.2)
		return


func _on_landed() -> void:
	var hard := _fall_speed > 6.0
	_stone_floor = _floor_is_stone()
	if hard:
		_dust.global_position = global_position
		_dust.restart()
		_squash(Vector3(1.15, 0.8, 1.15))
	Sound.play("land", linear_to_db(clamp(_fall_speed / 18.0, 0.15, 1.0)) - 6.0)


func _floor_is_stone() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y > 0.6:
			var o := c.get_collider()
			return o != null and not o.has_meta("terrain")
	return false


func _squash(s: Vector3) -> void:
	model.scale = s
	create_tween().tween_property(model, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func set_gliding(on: bool) -> void:
	if on == gliding:
		return
	gliding = on
	if on and carrying:
		drop_carried(true)  # you can jump and fall with a stone, but not fly with one
	if on:
		var hv := Vector3(velocity.x, 0, velocity.z)
		glide_heading = hv.normalized() if hv.length() > 1.0 else -model.global_basis.z.slide(Vector3.UP).normalized()
		_prev_heading_yaw = atan2(-glide_heading.x, -glide_heading.z)
		Sound.play("glider_open", -6.0, randf_range(0.95, 1.05))


## Boost ring: fling along `v` and hold extra speed for a moment.
func boost(v: Vector3) -> void:
	velocity = v
	set_gliding(true)
	glide_heading = Vector3(v.x, 0, v.z).normalized()
	_boost = 1.4
	_boost_speed = Vector3(v.x, 0, v.z).length()
	_fov_kick = 1.0


## Launch pad: shoot straight up.
func launch(power: float) -> void:
	set_gliding(false)
	velocity.y = power
	_boost = 0.6
	_air_time = 0.3
	_fov_kick = 0.6
	_squash(Vector3(0.8, 1.3, 0.8))


## Ground marker under the Wanderer while airborne, plus a soft personal light at night.
func _update_marker(on_floor: bool) -> void:
	var show := not on_floor
	if show:
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 120.0, 1 | 2 | 8)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		show = not hit.is_empty() and global_position.y - hit.position.y > 0.6
		if show:
			var h: float = global_position.y - hit.position.y
			_marker.global_position = hit.position + Vector3.UP * 0.05
			_marker.scale = Vector3.ONE * clamp(0.7 + h * 0.025, 0.7, 2.0)
			(_marker.material_override as ShaderMaterial).set_shader_parameter("alpha", clamp(1.0 - h / 90.0, 0.35, 0.85))
	_marker.visible = show
	var s := ElUtil.session(self)
	var night := 0.0
	if s and s.cycle:
		night = 1.0 - s.cycle.daylight()
	_night_light.light_energy = night * 1.1
	_night_light.visible = night > 0.02


func _update_block(dt: float) -> void:
	var want := debug_block or (input_enabled and Input.is_action_pressed("block") and carrying == null and not holding_orb)
	if want and not blocking and stamina > 0.25:
		blocking = true
		ElUtil.hint(self, "block_use", "Your shield blocks orbs and wisps, but tires quickly. Release it to recover.")
	elif blocking and (not want or stamina <= 0.0):
		blocking = false
		_stamina_wait = 0.6
	if blocking:
		stamina = max(0.0, stamina - dt * 0.25)
	else:
		_stamina_wait -= dt
		if _stamina_wait <= 0.0:
			stamina = min(1.0, stamina + dt * 0.5)
	_shield.visible = blocking
	if blocking:
		var s := 1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.02
		_shield.scale = Vector3.ONE * s
	get_tree().call_group("hud", "set_stamina", stamina, blocking)


## Returns true if the hit landed (false when invulnerable or blocked).
func damage(amount: int, from: Vector3) -> bool:
	if _invuln > 0.0:
		return false
	var away := global_position - from
	away.y = 0.0
	if blocking:
		stamina = max(0.0, stamina - 0.25)
		velocity += away.normalized() * 3.0
		_invuln = 0.3
		Sound.play("gate", -4.0, 0.7)
		_shield.scale = Vector3.ONE * 1.25
		return false
	_invuln = 1.5
	hits += 1
	health -= amount
	velocity = away.normalized() * 6.0 + Vector3.UP * 4.0
	set_gliding(false)
	Sound.play("hurt", -2.0)
	hurt.emit()
	get_tree().call_group("hud", "set_health", health)
	if health <= 0:
		died.emit()
	return true


func heal_full() -> void:
	health = MAX_HEALTH
	get_tree().call_group("hud", "set_health", health)


## Falling off the world: counts as a fall, and costs a heart in Challenge mode
## (where the manual return key costs one too).
func respawn(fell_off := false) -> void:
	fell.emit()
	if fell_off:
		falls += 1
	get_tree().call_group("gate_course", "reset_run")
	if Settings.get_v("challenge"):
		health -= 1
		Sound.play("hurt", -6.0, 0.8)
		get_tree().call_group("hud", "set_health", health)
		if health <= 0:
			died.emit()
			return
	_invuln = 1.5
	var p := last_safe
	if not has_ground(p):
		var s := ElUtil.session(self)
		p = s.checkpoint_pos if s and has_ground(s.checkpoint_pos) else (s.level.spawn_point if s else p)
		last_safe = p
	teleport(p + Vector3.UP * 0.5)


## True if there is solid, static ground just below `p` (guards against bad respawn points).
func has_ground(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p + Vector3.DOWN * 3.0, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider is StaticBody3D and not hit.collider.has_meta("unsafe")


func teleport(p: Vector3) -> void:
	if carrying:
		carrying.go_home()
	set_gliding(false)
	velocity = Vector3.ZERO
	global_position = p
	pivot.global_position = global_position + Vector3(0, 1.5, 0)


func _strongest_updraft() -> Updraft:
	var best: Updraft = null
	var best_lift := 0.0
	for u: Updraft in updrafts:
		var l := u.lift_at(global_position)
		if l > best_lift:
			best_lift = l
			best = u
	return best


func _track_safe(dt: float) -> void:
	_safe_timer += dt
	if _safe_timer < 0.4:
		return
	# Only solid, static, permanent ground counts: not stones, ferries, crumbling or day/night slabs.
	if get_floor_normal().y > 0.85 and has_ground(global_position):
		_safe_timer = 0.0
		last_safe = global_position


func _find_interactable() -> void:
	if carrying:
		interact_target = carrying
		var text := "Place on plate" if _plate_target() else "Set down"
		if text != _carry_prompt:
			_carry_prompt = text
			get_tree().call_group("hud", "set_prompt", Settings.prompt("interact", text))
		return
	var best: Node3D = null
	var best_d := 2.8
	for n in get_tree().get_nodes_in_group("interactable"):
		var d := (n as Node3D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = n
	if best != interact_target:
		interact_target = best
		get_tree().call_group("hud", "set_prompt", "" if best == null else Settings.prompt("interact", best.interact_prompt()))


func _update_visuals(dt: float, on_floor: bool) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z)
	var face := glide_heading if gliding else hv
	if face.length() > 0.3:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-12.0 * dt))
	var spd := hv.length()
	_anim_t += dt * (2.0 + spd * 1.6)
	var bob := 0.0
	if on_floor and spd > 0.5:
		bob = abs(sin(_anim_t)) * 0.06 * clamp(spd / RUN_SPEED, 0.3, 1.0)
		var phase: float = floor(_anim_t / PI)
		if phase != _step_phase:
			_step_phase = phase
			if get_slide_collision_count() > 0:
				_stone_floor = _floor_is_stone()
			Sound.play_step(_stone_floor)
	model.position.y = lerp(model.position.y, bob, 1.0 - exp(-20.0 * dt))

	var lean: float = -0.16 * clamp(spd / RUN_SPEED, 0.0, 1.0) if on_floor else 0.0
	var roll := 0.0
	if gliding:
		lean = -0.3
		var hy := atan2(-glide_heading.x, -glide_heading.z)
		roll = clamp(angle_difference(_prev_heading_yaw, hy) / max(dt, 0.001) * 0.35, -0.5, 0.5)
		_prev_heading_yaw = hy
		if Settings.get_v("camera_auto") and _mouse_idle > 0.8:
			yaw = lerp_angle(yaw, hy, 1.0 - exp(-1.2 * dt))
			pitch = lerp(pitch, -0.2, 1.0 - exp(-1.0 * dt))
	elif Touch.active and Settings.get_v("camera_auto") and _mouse_idle > 0.6 and spd > 1.0:
		# Touch: the camera eases in behind the direction you walk, so you rarely need to drag.
		# Walking back toward the camera leaves it alone (it would spin around otherwise).
		var my := atan2(-velocity.x, -velocity.z)
		if absf(angle_difference(yaw, my)) < 2.0:
			yaw = lerp_angle(yaw, my, 1.0 - exp(-0.9 * clamp(spd / RUN_SPEED, 0.3, 1.0) * dt))
	model.rotation.x = lerp(model.rotation.x, lean, 1.0 - exp(-8.0 * dt))
	model.rotation.z = lerp(model.rotation.z, roll, 1.0 - exp(-5.0 * dt))
	model.visible = _invuln <= 0.0 or fmod(_invuln, 0.2) > 0.1

	_glide_amount = move_toward(_glide_amount, 1.0 if gliding else 0.0, dt * 4.0)
	glider.visible = _glide_amount > 0.01
	glider.scale = Vector3.ONE * max(0.01, smoothstep(0.0, 1.0, _glide_amount))

	_fov_kick = move_toward(_fov_kick, 0.0, dt * 0.8)
	pivot.global_position = pivot.global_position.lerp(global_position + Vector3(0, 1.5, 0), 1.0 - exp(-10.0 * dt))
	pivot.rotation = Vector3(pitch, yaw, 0)
	spring.spring_length = lerp(spring.spring_length, 6.5 if gliding else 4.5, 1.0 - exp(-2.0 * dt))
	var base_fov: float = Settings.get_v("fov")
	camera.fov = lerp(camera.fov, base_fov + (10.0 if gliding else 0.0) + _fov_kick * 14.0, 1.0 - exp(-3.0 * dt))
	_update_marker(on_floor)
	var air: float = clamp((velocity.length() - 6.0) / 14.0, 0.0, 1.0) if not on_floor else 0.0
	Sound.set_wind(air * 0.9 + (0.12 if gliding else 0.0))
