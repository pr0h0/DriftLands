class_name Session
extends Node3D
## One playthrough of a level: world, player, HUD, pause, shards, checkpoints, completion.
##
## Debug args (after `--`, with --level=N):
##   --shot=out.png [--frames=90] [--hour=17.2] [--hidehud]
##   [--cam=x,y,z --look=x,y,z]  or  [--player=x,y,z --yaw=deg --pitch=deg --glide]
##   --probe=seconds --player=x,y,z [--heading=deg]   logs the player's position over time

signal ready_to_play
signal to_menu
signal to_level(id: int, resume: bool)

var level_id := 1
var resume := false
var args := {}

var cycle: SkyCycle
var level: LevelBase
var player: Player
var hud: Hud
var pause_menu: PauseMenu
var collected: Array = []
var lives := 3
var checkpoint_pos: Vector3
var elapsed := 0.0
var finished := false
var _hinted := {}
var _was_captured := false
var _photo: PhotoMode
var carried_orb: Shard
var beacon_awake := false
var _clock_stopped := false
var _finish_time := 0.0
var _ascending := false
var _ascend_at := Vector3.INF  # where the beacon beam (or escape beam) lifts you out
var _collapse_left := -1.0
var _collapse_fx: Node3D
var _rumble: AudioStreamPlayer


func _ready() -> void:
	# Main runs while paused (for F11); the game world itself must stop when paused.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("session")
	if args.has("hud"):
		Settings.values["hud_layout"] = int(args["hud"])
	if args.has("challenge"):
		Settings.values["challenge"] = true
	level = Levels.make(level_id)
	cycle = SkyCycle.new()
	cycle.configure(level.sky)
	if args.has("hour"):
		cycle.hour = float(args["hour"])
	add_child(cycle)
	level.cycle = cycle
	level.session = self
	add_child(level)
	await level.build()

	player = Player.new()
	if args.has("mask"):
		player.model_asset = "wanderer_" + String(args["mask"])
	player.position = level.spawn_point
	player.yaw = level.spawn_yaw
	player.kill_y = level.kill_y
	add_child(player)
	level.follow = player
	player.fell.connect(func(): hud.flash(0.7); _drop_orb())
	player.hurt.connect(_drop_orb)
	player.died.connect(_on_died)
	lives = Difficulty.lives()
	if Difficulty.extra_guards():
		for sh in level.shards:
			level.wisp(sh.global_position + Vector3(0, 2.5, 0), 4.5)
	hud = Hud.new()
	add_child(hud)
	hud.setup(level.shards.size())
	hud.set_lives(lives if Settings.get_v("challenge") else -1)
	var found: Array = Progress.fragments(level_id)
	for i in level.fragments.size():
		var f: Fragment = level.fragments[i]
		f.index = i
		if i in found:
			f.queue_free()
		else:
			f.found.connect(_on_fragment)
	hud.set_fragments(found.size(), level.fragments.size())
	player.hurt.connect(func(): first_hint("block", "Hold %s (or right mouse) to raise your shield." % Settings.key_label("block")))
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.resumed.connect(func(): _pause(false))
	pause_menu.restart_checkpoint.connect(func(): _pause(false); player.teleport(checkpoint_pos))
	pause_menu.restart_level.connect(func(): Progress.clear_checkpoint(); to_level.emit(level_id, false))
	pause_menu.quit_to_menu.connect(func(): to_menu.emit())
	pause_menu.photo.connect(open_photo_mode)
	for i in level.shards.size():
		level.shards[i].index = i
		level.shards[i].collected.connect(_on_shard_collected)
	checkpoint_pos = level.spawn_point
	if resume:
		await _apply_checkpoint()
	Sound.music(level.mood)
	ready_to_play.emit()

	if args.has("shot"):
		await _screenshot()
		return
	if args.has("probe"):
		await _probe()
		return
	if args.has("phototest"):
		var start := player.global_position
		open_photo_mode()
		Input.action_press("move_forward")
		for i in 60:
			await get_tree().process_frame
		Input.action_release("move_forward")
		print("PHOTOTEST player moved %.2f m, camera moved %.2f m" % [player.global_position.distance_to(start), _photo.cam.global_position.distance_to(player.camera.global_position)])
		get_tree().quit()
		return
	if args.has("mirrortest"):
		await _mirror_test()
		return
	if args.has("audit"):
		await _audit()
		return
	if args.has("beamtrace"):
		var em: BeamEmitter = level.find_children("*", "BeamEmitter", true, false)[int(args["beamtrace"])]
		for m: Mirror in level.find_children("*", "Mirror", true, false):
			Assets.find(m, "MirrorFrame").rotation.y = PI / 4.0
		for i in 4:
			await get_tree().physics_frame
		var o := em.global_position + Vector3.UP * BeamEmitter.HEIGHT
		var d := -em.global_basis.z
		for i in 4:
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + d * 80.0, 1 | 2 | 16))
			if hit.is_empty():
				print("seg %d from %s: no hit" % [i, o.snappedf(0.1)])
				break
			var c: Node = hit.collider
			print("seg %d from %s dir %s -> hit %s at %s (%s)" % [i, o.snappedf(0.1), d.snappedf(0.01), c.get_path(), (hit.position as Vector3).snappedf(0.1), c.get_meta_list()])
			if not c.has_meta("mirror"):
				break
			d = d.bounce(hit.normal).normalized()
			d.y = 0
			o = hit.position + d * 0.05
		get_tree().quit()
		return
	if args.has("featuretest"):
		await _feature_test()
		return
	if args.has("beamtest"):
		await _beam_test()
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_title(level.title, level.subtitle)
	level.on_start()


func _process(dt: float) -> void:
	if finished or get_tree().paused:
		return
	if not _clock_stopped:
		elapsed += dt
	_update_orb()
	_update_collapse(dt)
	if _photo:
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_was_captured = true
	elif _was_captured and OS.has_feature("web"):
		_pause(true)  # browser released pointer lock (Esc)


func open_photo_mode() -> void:
	if _photo:
		return
	pause_menu.close()
	get_tree().paused = true
	_photo = PhotoMode.new()
	_photo.session = self
	add_child(_photo)
	_photo.closed.connect(func(): _photo = null; get_tree().paused = false; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; _was_captured = false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("photo") and not finished and _photo == null:
		get_viewport().set_input_as_handled()
		open_photo_mode()
		return
	if event.is_action_pressed("pause") and not finished and not get_tree().paused:
		get_viewport().set_input_as_handled()
		_pause(true)


func _pause(on: bool) -> void:
	get_tree().paused = on
	_was_captured = false
	if on:
		pause_menu.open()
		Sound.set_wind(0.0)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		pause_menu.close()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Hints shown once per session (unless the player turned hints off).
func first_hint(key: String, text: String) -> void:
	if _hinted.has(key) or not Settings.get_v("hints") or hud == null:
		return
	_hinted[key] = true
	hud.hint(text)


func set_checkpoint(pos: Vector3) -> void:
	checkpoint_pos = pos
	player.heal_full()
	Progress.set_checkpoint(level_id, collected, pos, elapsed, lives)
	hud.hint("Hearts restored", 2.0)


func _apply_checkpoint() -> void:
	var cp := Progress.checkpoint()
	if cp.is_empty() or int(cp["level"]) != level_id:
		return
	elapsed = float(cp.get("time", 0.0))
	lives = int(cp.get("lives", Difficulty.lives()))
	hud.set_lives(lives)
	var p: Array = cp["pos"]
	checkpoint_pos = Vector3(p[0], p[1], p[2])
	await get_tree().physics_frame
	if not player.has_ground(checkpoint_pos):
		checkpoint_pos = level.spawn_point
	player.teleport(checkpoint_pos)
	player.last_safe = checkpoint_pos
	for idx in cp["shards"]:
		var s: Shard = level.shards[int(idx)]
		s.taken = true
		collected.append(int(idx))
		_light_band(collected.size() - 1, s, true)
	hud.set_shards(collected.size())


func _on_fragment(f: Fragment) -> void:
	Progress.add_fragment(level_id, f.index)
	var n := Progress.fragments(level_id).size()
	hud.set_fragments(n, level.fragments.size())
	hud.hint("Light fragment  %d / %d" % [n, level.fragments.size()], 2.5)


## Out of hearts. Practice: back to the last checkpoint with full hearts.
## Challenge: lose a life and wake on the middle island (shards kept); out of lives restarts.
func _on_died(cost_life := true) -> void:
	if finished:
		return
	if not Settings.get_v("challenge"):
		hud.flash(0.9, Color(0.1, 0.05, 0.1))
		var p := level.spawn_point
		player.teleport(p)
		player.last_safe = p
		player.heal_full()
		player._invuln = 2.0
		return
	if cost_life:
		lives -= 1
		hud.set_lives(lives)
	if lives <= 0:
		finished = true
		player.input_enabled = false
		player.set_physics_process(false)
		player.velocity = Vector3.ZERO
		hud.flash(1.0, Color(0.05, 0.03, 0.06))
		hud.show_title("The light fades", "out of lives · the level begins again", 1.5)
		Progress.clear_checkpoint()
		await get_tree().create_timer(4.0).timeout
		to_level.emit(level_id, false)
		return
	hud.flash(0.9, Color(0.1, 0.05, 0.1))
	if cost_life:
		hud.hint("A life is lost. %d left." % lives, 3.0)
	player.teleport(level.spawn_point)
	player.last_safe = level.spawn_point
	player.heal_full()
	player._invuln = 2.0
	Progress.set_checkpoint(level_id, collected, level.spawn_point, elapsed, lives)


# ------------------------------------------------------------ light orbs (carried shards)

func _pick_orb(shard: Shard) -> void:
	if shard.home_pos == Vector3.ZERO:
		shard.home_pos = shard.global_position
	carried_orb = shard
	player.holding_orb = true
	Sound.play("collect", -6.0, 0.8)
	hud.hint("A heavy light. Carry it to the beacon. Hands full: no shield, no running. A hit or a fall sends it home.", 6.0)


func _update_orb() -> void:
	if carried_orb == null:
		return
	var t := Time.get_ticks_msec() * 0.003
	carried_orb.global_position = player.global_position + Vector3(0, 2.4 + sin(t) * 0.08, 0)
	var to := level.monolith.global_position - player.global_position
	if Vector2(to.x, to.z).length() < 8.0 and absf(to.y) < 6.0:
		var s := carried_orb
		carried_orb = null
		player.holding_orb = false
		s.delivered = true
		_on_shard_collected(s)


func _drop_orb() -> void:
	if carried_orb == null:
		return
	var s := carried_orb
	carried_orb = null
	player.holding_orb = false
	hud.hint("The light slipped away and drifted back to its shrine.", 3.5)
	Sound.play("gate_fail", -6.0)
	var t := create_tween()
	t.tween_property(s, "global_position", s.home_pos, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func(): s.taken = false)


## Where the compass should point: the beacon/escape beam, the beacon while carrying an orb,
## otherwise the nearest remaining shard. Vector3.INF = nothing.
func compass_target(from: Vector3) -> Vector3:
	if _ascend_at != Vector3.INF:
		return _ascend_at
	if carried_orb:
		return level.monolith.global_position
	var best := Vector3.INF
	for sh in level.shards:
		if is_instance_valid(sh) and not sh.taken and from.distance_to(sh.global_position) < from.distance_to(best):
			best = sh.global_position
	return best


func _on_shard_collected(shard: Shard) -> void:
	if shard.carry and not shard.delivered:
		_pick_orb(shard)
		return
	shard.set_deferred("monitoring", false)
	var band := collected.size()
	collected.append(shard.index)
	hud.set_shards(collected.size())
	Sound.play("collect", -2.0)
	var total := level.shards.size()
	var msgs := ["The first shard stirs.", "A second light returns.", "The last shard. The beacon wakes."]
	hud.hint(msgs[min(band, 2)] if band < total - 1 or total == 3 else "The beacon wakes.", 3.5)
	if player.has_ground(player.last_safe):
		checkpoint_pos = player.last_safe
	player.heal_full()
	if collected.size() < total:
		Progress.set_checkpoint(level_id, collected, checkpoint_pos, elapsed, lives)
	var start := shard.global_position
	var end: Vector3 = level.monolith.global_transform * Vector3(0, 2.5 + band * 1.9, 0)
	var ctrl := start.lerp(end, 0.5) + Vector3(0, 30, 0)
	var tw := create_tween()
	tw.tween_method(func(t: float): shard.global_position = _bezier(start, ctrl, end, t), 0.0, 1.0, 3.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): _light_band(band, shard))


func _bezier(a: Vector3, c: Vector3, b: Vector3, t: float) -> Vector3:
	return a.lerp(c, t).lerp(c.lerp(b, t), t)


func _light_band(band: int, shard: Shard, instant := false) -> void:
	shard.queue_free()
	var runes := Assets.find(level.monolith, "Runes%d" % (band + 1)) as MeshInstance3D
	if runes:
		var m := (Mats.get_mat("rune") as StandardMaterial3D).duplicate() as StandardMaterial3D
		runes.material_override = m
		if instant:
			m.emission_energy_multiplier = 5.0
		else:
			create_tween().tween_property(m, "emission_energy_multiplier", 5.0, 1.5)
			Sound.play_at("shard_chime", level.monolith.global_position)
	if instant:
		return
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.55, 0.85, 1.0)
	flash.omni_range = 18.0
	flash.position = Vector3(0, 2.5 + band * 1.9, 0)
	level.monolith.add_child(flash)
	var t := create_tween()
	t.tween_property(flash, "light_energy", 6.0, 0.2)
	t.tween_property(flash, "light_energy", 1.2, 2.0)
	if collected.size() >= level.shards.size():
		_finale()


func _finale() -> void:
	var top := Node3D.new()
	top.position = Vector3(0, 8.6, 0)
	level.monolith.add_child(top)
	top.add_child(FX.beam(1.0, 600.0, Color(0.6, 0.9, 1.0), 2.5))
	top.scale = Vector3(1, 0.001, 1)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.6, 0.9, 1.0)
	glow.omni_range = 40.0
	glow.light_energy = 0.0
	top.add_child(glow)
	var t := create_tween().set_parallel(true)
	t.tween_property(top, "scale:y", 1.0, 4.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_property(glow, "light_energy", 4.0, 4.0)
	Sound.play("beacon")
	Sound.music("triumph")
	level.celebrate()
	level.on_finale()
	beacon_awake = true
	if level.escape:
		await get_tree().create_timer(3.0).timeout
		_start_collapse()
		return
	# Normal levels: the clock stops now; step into the beacon's light to rise out of the level.
	_clock_stopped = true
	_finish_time = elapsed
	var base := level.monolith.global_position
	_add_ascend_beam(base, 3.4)
	await get_tree().create_timer(4.5).timeout
	hud.hint("The beacon is awake. Step into its light.", 6.0)


## A soft column of light around `base`; entering it carries the Wanderer up and ends the level.
func _add_ascend_beam(base: Vector3, radius: float) -> void:
	_ascend_at = base
	var col := FX.beam(radius, 400.0, Color(1.0, 0.92, 0.7), 0.7)
	col.position = base
	level.add_child(col)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 4
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 12.0
	cs.shape = cyl
	cs.position.y = 5.0
	area.add_child(cs)
	area.position = base
	level.add_child(area)
	area.body_entered.connect(func(b): if b is Player: _ascend(base))


func _ascend(center: Vector3) -> void:
	if _ascending or finished:
		return
	_ascending = true
	if not _clock_stopped:
		_clock_stopped = true
		_finish_time = elapsed
	_stop_collapse()
	hud.clear_timer()
	_drop_orb()
	player.input_enabled = false
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.glider.visible = true
	player.glider.scale = Vector3.ONE
	Sound.play("launch", -2.0, 0.8)
	var start := player.global_position
	var r0 := Vector2(start.x - center.x, start.z - center.z).length()
	var a0 := atan2(start.z - center.z, start.x - center.x)
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var a := a0 + k * TAU * 1.25
		var r: float = lerp(r0, 1.2, minf(k * 2.0, 1.0))
		player.global_position = Vector3(center.x + cos(a) * r, start.y + k * k * 80.0, center.z + sin(a) * r)
		player.model.rotation.y = -a
		player.model.rotation.x = -0.3
		player.pitch = lerp(player.pitch, 0.55, 0.03)
		player.pivot.global_position = player.pivot.global_position.lerp(player.global_position + Vector3(0, 1.5, 0), 0.03)
		player.pivot.rotation = Vector3(player.pitch, player.yaw, 0), 0.0, 1.0, 5.0)
	tw.parallel().tween_callback(func(): hud.flash(1.0)).set_delay(4.2)
	await tw.finished
	_complete(_finish_time)


func _complete(time: float) -> void:
	finished = true
	var best := Progress.complete(level_id, time)
	var par := level.par_time * Difficulty.par_scale()
	var ch := Progress.record_challenges(level_id, {
		"flawless": player.falls == 0 and player.hits == 0,
		"time": time <= par,
		"fragments": Progress.fragments(level_id).size() >= Difficulty.fragments_needed(level.fragments.size()),
	})
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.input_enabled = false
	var cs := CompleteScreen.new().setup(level_id, time, best, ch, par)
	add_child(cs)
	cs.next_level.connect(func(): to_level.emit(level_id + 1, false))
	cs.replay.connect(func(): to_level.emit(level_id, false))
	cs.quit_to_menu.connect(func(): to_menu.emit())


# ------------------------------------------------------------ chapter finale: the island falls

func _start_collapse() -> void:
	var c := level.monolith.global_position
	var r := level.island_radius_at(c)
	var plat: Vector3 = await level.build_escape()
	_add_ascend_beam(plat, 3.4)
	_collapse_left = level.escape_time
	hud.show_title("The island is falling", "ride the rings to the far platform before it's gone", 2.5)
	Sound.play("rumble", 0.0)
	_rumble = AudioStreamPlayer.new()
	_rumble.stream = Sound.looped("rumble")
	_rumble.bus = "SFX"
	_rumble.volume_db = -8.0
	add_child(_rumble)
	_rumble.play()
	_collapse_fx = level.collapse_fx(c, r)


func _update_collapse(dt: float) -> void:
	if _collapse_left < 0.0 or _ascending:
		return
	_collapse_left -= dt
	hud.set_timer(_collapse_left)
	var shake := 0.05 + 0.1 * clampf(1.0 - _collapse_left / level.escape_time, 0.0, 1.0)
	player.camera.h_offset = randf_range(-shake, shake)
	player.camera.v_offset = randf_range(-shake, shake)
	if _collapse_left <= 0.0:
		_collapse_left = -1.0
		_collapse_failed()


func _stop_collapse() -> void:
	_collapse_left = -1.0
	player.camera.h_offset = 0.0
	player.camera.v_offset = 0.0
	if _rumble:
		create_tween().tween_property(_rumble, "volume_db", -60.0, 2.0)
	if _collapse_fx:
		_collapse_fx.queue_free()


## Too slow: the island takes every life with it and the level begins again.
func _collapse_failed() -> void:
	_stop_collapse()
	hud.clear_timer()
	finished = true
	player.input_enabled = false
	player.set_physics_process(false)
	lives = 0
	hud.set_lives(0)
	hud.flash(1.0, Color(0.05, 0.03, 0.06))
	hud.show_title("The island is gone", "all lives lost · the level begins again", 1.5)
	Progress.clear_checkpoint()
	await get_tree().create_timer(4.0).timeout
	to_level.emit(level_id, false)


# ------------------------------------------------------------ debug modes

func _vec(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _probe() -> void:
	player.input_enabled = false
	player.teleport(_vec(args["player"]))
	if args.has("pull"):
		var levers := level.find_children("*", "Lever", true, false)
		for k in int(args["pull"]):
			for lv: Lever in levers:
				lv._cool = 0.0
				lv.interact()
			await get_tree().create_timer(2.8).timeout
		var turns := level.find_children("*", "Turning", true, false).map(func(t): return "%s yaw=%d" % [t.global_position.snappedf(1), roundi(rad_to_deg(t.rotation.y))])
		print("turnings: ", turns)
	if args.has("walk"):
		var w: PackedStringArray = String(args["walk"]).split(",")
		player.debug_dir = Vector3(float(w[0]), 0, float(w[1]))
	if args.has("block"):
		player.debug_block = true
	if args.has("dive"):
		player.debug_dive = true
		player.set_gliding(true)
	if args.has("vy"):
		player.velocity.y = float(args["vy"])
	if args.has("badsafe"):
		player.last_safe = player.global_position  # reproduce: "safe" point in mid-air
	if args.has("heading"):
		var a := deg_to_rad(float(args["heading"]))
		player.velocity = Vector3(-sin(a), 0, -cos(a)) * 10.0
		player.set_gliding(true)
		player.glide_heading = Vector3(-sin(a), 0, -cos(a))
	for i in int(float(args["probe"]) * 2.0):
		await get_tree().create_timer(0.5).timeout
		var extra := ""
		for st in level.find_children("*", "PushStone", true, false):
			if st.global_position.distance_to(player.global_position) < 15.0:
				extra += " stone=%s" % st.global_position.snappedf(0.1)
		print("t=%.1f pos=%s gliding=%s floor=%s hp=%d lives=%d frags=%d%s" % [(i + 1) * 0.5, player.global_position.snappedf(0.1), player.gliding, player.is_on_floor(), player.health, lives, Progress.fragments(level_id).size(), extra])
	get_tree().quit()


## For each beam receiver, brute-forces the mirrors near it and reports whether any setting lights it.
func _mirror_test() -> void:
	for i in 4:
		await get_tree().physics_frame
	var all_m := level.find_children("*", "Mirror", true, false)
	var out := []
	for r: BeamReceiver in get_tree().get_nodes_in_group("beam_receiver"):
		var near := all_m.filter(func(m): return m.global_position.distance_to(r.global_position) < 16.0)
		var ok := near.is_empty() and r.lit
		var start: Array = near.map(func(m): return m.step)
		var found := ""
		for c in int(pow(8, near.size())):
			var k := c
			for m: Mirror in near:
				m.step = k % 8
				k /= 8
				Assets.find(m, "MirrorFrame").rotation.y = m.step * PI / 4.0
			for i in 3:
				await get_tree().physics_frame
			if r.lit:
				ok = true
				found = str(near.map(func(m): return m.step))
				break
		out.append("receiver %s mirrors=%d start=%s -> %s %s" % [r.global_position.snappedf(1), near.size(), start, "SOLVABLE" if ok else "UNSOLVABLE", found])
	print("MIRRORTEST level %d:\n  %s" % [level_id, "\n  ".join(out) if not out.is_empty() else "(no receivers)"])
	get_tree().quit()


## Level sanity audit: overlapping islands, things without ground, shard/fragment counts.
func _audit() -> void:
	for i in 4:
		await get_tree().physics_frame
	var issues := []
	var isl: Array = level._islands
	for i in isl.size():
		for j in range(i + 1, isl.size()):
			var a: Dictionary = isl[i]
			var b: Dictionary = isl[j]
			var hd := Vector2(a.pos.x - b.pos.x, a.pos.z - b.pos.z).length()
			if hd < a.r + b.r + 2.0 and absf(a.pos.y - b.pos.y) < 20.0:
				issues.append("islands overlap: %s r%.0f / %s r%.0f (dist %.1f)" % [a.pos.snappedf(1), a.r, b.pos.snappedf(1), b.r, hd])
	var space := get_world_3d().direct_space_state
	var check := func(label: String, p: Vector3, reach: float):
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p + Vector3.DOWN * reach, 1 | 2))
		if hit.is_empty():
			issues.append("%s has no ground near %s" % [label, p.snappedf(0.1)])
	for s in level.shards:
		check.call("shard", s.global_position, 4.0)
	for u in level.find_children("*", "Updraft", true, false):
		check.call("vent", u.global_position, 2.0)
	for n in level.find_children("*", "LaunchPad", true, false) + level.find_children("*", "Lever", true, false) + level.find_children("*", "Bell", true, false) + level.find_children("*", "Mushroom", true, false):
		check.call(n.get_class() if n.get_script() == null else n.get_script().get_global_name(), n.global_position, 2.0)
	for st in get_tree().get_nodes_in_group("push_stone"):
		check.call("push stone", st.global_position, 2.0)
	for pl in level.find_children("*", "PressurePlate", true, false):
		check.call("plate", pl.global_position, 2.0)
	if level.find_children("*", "LoreStone", true, false).is_empty():
		issues.append("no lore stone")
	if level.shards.size() != 3:
		issues.append("shards: %d" % level.shards.size())
	if level.fragments.size() != 5:
		issues.append("fragments: %d" % level.fragments.size())
	print("AUDIT level %d: %s" % [level_id, "OK" if issues.is_empty() else "\n  " + "\n  ".join(issues)])
	get_tree().quit()


## Exercises stone carrying, light-orb delivery, the beacon ascent and the escape.
func _feature_test() -> void:
	var wait := func(sec: float): await get_tree().create_timer(sec).timeout
	await wait.call(0.5)
	var stones := get_tree().get_nodes_in_group("push_stone")
	if not stones.is_empty():
		var st: PushStone = stones[0]
		player.teleport(st.global_position + Vector3(1.4, 0.3, 0))
		await wait.call(0.5)
		st.interact()
		print("FT stone lifted=%s" % (player.carrying == st))
		player.debug_dir = Vector3(0, 0, 1)
		await wait.call(1.0)
		player.debug_dir = Vector3.ZERO
		player.drop_carried(false)
		await wait.call(1.0)
		print("FT stone dropped at %s (player %s) carrying=%s" % [st.global_position.snappedf(0.1), player.global_position.snappedf(0.1), player.carrying])
	for sh in level.shards:
		if sh.carry:
			player.teleport(sh.global_position + Vector3(0, -1.0, 0))
			await wait.call(0.5)
			print("FT orb picked=%s" % (carried_orb == sh))
			player.respawn(true)
			await wait.call(2.0)
			print("FT orb after fall: carried=%s back_home=%s" % [carried_orb != null, sh.global_position.distance_to(sh.home_pos) < 0.5])
			player.teleport(sh.global_position + Vector3(0, -1.0, 0))
			await wait.call(0.5)
			player.teleport(level.monolith.global_position + Vector3(0, 0.5, 5.5))
			await wait.call(0.5)
			print("FT orb delivered=%s collected=%s" % [sh.delivered, collected])
	for sh in level.shards:
		if is_instance_valid(sh) and not sh.taken:
			sh.taken = true
			sh.delivered = true
			_on_shard_collected(sh)
	await wait.call(5.0)
	print("FT beacon_awake=%s escape=%s" % [beacon_awake, level.escape])
	if level.escape:
		if args.has("collapsefail"):
			await wait.call(3.0)
			_collapse_left = 2.0
			await wait.call(3.0)
			print("FT collapse failed: finished=%s lives=%d" % [finished, lives])
			get_tree().quit()
			return
		await wait.call(3.0)
		print("FT escape platform %s timer %.1f" % [_ascend_at.snappedf(0.1), _collapse_left])
	player.teleport(_ascend_at + Vector3(1.5, 0.3, 0))
	await wait.call(7.0)
	print("FT finished=%s time=%.1f done=%s" % [finished, _finish_time, Progress.level_info(level_id).get("done", false)])
	get_tree().quit()


## Brute-forces every mirror orientation and reports which ones light all receivers.
func _beam_test() -> void:
	var mirrors := level.find_children("*", "Mirror", true, false)
	var receivers := get_tree().get_nodes_in_group("beam_receiver")
	var combos := int(pow(8, mirrors.size()))
	var solutions := []
	for c in combos:
		var k := c
		for m: Mirror in mirrors:
			m.step = k % 8
			k /= 8
			Assets.find(m, "MirrorFrame").rotation.y = m.step * PI / 4.0
		for i in 3:
			await get_tree().physics_frame
		var lit_now := []
		for ri in receivers.size():
			if receivers[ri].lit:
				lit_now.append(ri)
		if lit_now.size() >= 2 and solutions.size() < 12:
			solutions.append("%s:%s" % [lit_now, mirrors.map(func(m): return m.step)])
	print("mirrors=%s receivers=%d" % [mirrors.map(func(m): return m.global_position.snappedf(1)), receivers.size()])
	for s in solutions:
		print("  lit ", s)
	get_tree().quit()


func _screenshot() -> void:
	cycle.paused = true
	player.input_enabled = false
	if args.has("hidehud"):
		hud.visible = false
	if args.has("damage"):
		player.health = 2
		hud.set_health(2)
		player.falls = 1
		hud.set_stamina(0.6, true)
		hud.hint("Hold Q (or right mouse) to raise your shield.", 10.0)
	if args.has("player"):
		player.teleport(_vec(args["player"]))
	player.yaw = deg_to_rad(float(args.get("yaw", "0")))
	player.pitch = deg_to_rad(float(args.get("pitch", "-14")))
	player.model.rotation.y = player.yaw
	if args.has("glide"):
		player.set_gliding(true)
	if args.has("freeze"):
		# Hold a pose for portraits: open glider fully, lean, stop physics.
		if player.gliding:
			player._glide_amount = 1.0
			player.glider.visible = true
			player.glider.scale = Vector3.ONE
			player.model.rotation.x = -0.3
		player.set_physics_process(false)
	if args.has("wisp"):
		var w := Wisp.new()
		w.home = _vec(args["wisp"])
		w.radius = 0.6
		level.add_child(w)
	if args.has("cam"):
		var cam := Camera3D.new()
		cam.fov = float(args.get("fov", "65"))
		cam.far = 3000.0
		add_child(cam)
		cam.global_position = _vec(args["cam"])
		cam.look_at(_vec(args.get("look", "0,0,0")))
		cam.make_current()
		level.follow = cam
	for i in int(args.get("frames", "90")):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(args["shot"])
	print("saved ", args["shot"])
	get_tree().quit()
