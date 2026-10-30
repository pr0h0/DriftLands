class_name RunLevel
extends LevelKit
## Separate modes outside the campaign, built from the route kit:
##   "endless": an island chain that keeps generating ahead of you; lives run out on falls.
##   "trial":   a fixed course of hops against the clock, with medal times.

signal run_over(result: Dictionary)

var mode := "endless"
var seed_value := 1
var trial_hops := 8
var lives := 3
var chain: Array = []  # route islands in order (dictionaries from the kit)
var reached := 0
var medals := [0.0, 0.0, 0.0]  # gold, silver, bronze (seconds)
var _heading := 0.0
var _base_heading := 0.0
var _estimate := 0.0
var _chunks: Array = []  # [first island index, nodes]
var _extending := false
var _done := false
var _finish_mark: Node3D


func _init() -> void:
	mood = "bright"
	sky = {"hour": 16.8, "day_length": 3000.0, "clouds": 0.35}
	props = ["tree_a", "bush_a", "rock_a", "pine_a", "tree_blossom"]
	start_asset = "island_big"
	nature = true


## theme: "meadow", "frost" or "ember".
func configure(m: String, theme: String, s: int) -> void:
	mode = m
	seed_value = s
	match theme:
		"frost":
			palette = {"grass": "grass_snow", "rock": "rock_snow"}
			props = ["pine_a", "pine_b", "rock_a", "ice_spire"]
			weather = "snow"
			mood = "frost"
			sky = {"hour": 15.5, "day_length": 3000.0, "clouds": 0.4, "aurora": true}
			nature = false
		"ember":
			palette = {"grass": "grass_ash", "rock": "rock_ash"}
			props = ["dead_tree", "rock_a", "rock_c", "pillar_broken_a"]
			weather = "embers"
			mood = "storm"
			sky = {"hour": 17.4, "day_length": 3000.0, "clouds": 0.5, "fog": 1.3, "tint": Color(1.12, 0.82, 0.7)}
			nature = false


func islands() -> void:
	rng.seed = seed_value
	biome = palette.duplicate()
	spawn_point = Vector3(0, 1.5, 11)
	kill_y = -90.0
	S = _node(start_asset, Vector3.ZERO, 0.0)
	chain = [S]
	_base_heading = rng.randf_range(0.0, 360.0)
	_heading = _base_heading
	spawn_yaw = deg_to_rad(90.0 - _base_heading)
	var n := trial_hops if mode == "trial" else 5
	for i in n:
		_hop()
	distant_islands(16, palette)


func layout() -> void:
	plaza_monolith(S.pos)
	_reserve(Vector3(0, 0, 11), 3.0)
	for c in _later:
		c.call()
	_later.clear()
	_weather()
	for n in _deco:
		scatter(n.pos, n.r * 0.35 if n != S else 12.0, n.r * 0.92, int(n.r * 0.6), props, 0.75, 1.15, true, _avoid)
	_deco.clear()
	if mode == "trial":
		_mark_finish(chain[-1])
	_chunks.append([0, get_children()])


# ------------------------------------------------------------ route generation

## Adds one hop to the chain; harder kinds and enemies unlock further along.
func _hop() -> void:
	var cur: Dictionary = chain[-1]
	var i := chain.size()
	_heading = clampf(_heading + rng.randf_range(-28.0, 28.0), _base_heading - 55.0, _base_heading + 55.0)
	var a := _heading
	var small := ["island_small_a", "island_small_b", "island_small_c"]
	var mid := ["island_mid", "island_flat", "island_tall"]
	var asset: String = (small if rng.randf() < 0.45 else mid)[rng.randi() % 3]
	var kinds := ["glide", "vent", "slab"]
	if i >= 4:
		kinds += ["rings", "ferry", "crumble", "elevator"]
	if i >= 10:
		kinds += ["carousel", "crumble", "rings", "causeway"]
	var y: float = cur.pos.y
	if y > 28.0:
		kinds = ["glide", "glide", "crumble"]
	elif y < -12.0:
		kinds = ["vent", "elevator", "vent"]
	var k: String = kinds[rng.randi() % kinds.size()]
	var nxt: Dictionary
	match k:
		"glide":
			var drop := rng.randf_range(3.0, 7.0)
			nxt = glide(cur, a, drop, asset)
			_estimate += (nxt.pos - cur.pos).length() / 9.0
		"vent":
			var rise := rng.randf_range(8.0, 14.0)
			nxt = vent(cur, a, rise, asset)
			_estimate += rise / 4.0 + (nxt.pos - cur.pos).length() / 9.0 + 3.0
		"slab", "crumble":
			var cnt := rng.randi_range(3, 5)
			nxt = stones(cur, a, k, cnt, rng.randf_range(0.2, 0.8), asset)
			_estimate += cnt * 1.1 + 2.0
		"rings":
			nxt = rings(cur, a, rng.randi_range(2, 3), mid[rng.randi() % 3])
			_estimate += 14.0
		"ferry":
			nxt = ferry(cur, a, asset)
			_estimate += 16.0
		"elevator":
			nxt = elevator(cur, a, rng.randf_range(8.0, 14.0), asset)
			_estimate += 14.0
		"carousel":
			nxt = carousel_hop(cur, a)
			_estimate += 16.0
		"causeway":
			nxt = causeway(cur, a, 1, mid[rng.randi() % 3])
			_estimate += 18.0
	_estimate += float(nxt.r) / 4.0
	if mode == "endless" and i >= 8 and rng.randf() < 0.3 + minf(i * 0.01, 0.3):
		var c: Vector3 = nxt.pos
		var rr: float = nxt.r
		_later.append(func(): wisp(c + Vector3(0, 3.0, 0), rr * 0.6))
	if mode == "endless" and i >= 15 and rng.randf() < 0.2 and float(nxt.r) >= 9.0:
		var c2: Vector3 = nxt.pos
		_later.append(func(): sentinel(c2.x + 3.0, c2.z, c2.y))
	nxt["index"] = i
	chain.append(nxt)
	if mode == "trial":
		medals = [_estimate * 1.15, _estimate * 1.5, _estimate * 2.0]


## Endless: builds two more hops once the player gets close to the end of the chain.
func _extend() -> void:
	_extending = true
	var first := chain.size()
	var before := get_child_count()
	for i in 2:
		_hop()
	await get_tree().physics_frame
	await get_tree().physics_frame
	for c in _later:
		c.call()
	_later.clear()
	for n in _deco:
		scatter(n.pos, n.r * 0.35, n.r * 0.92, int(n.r * 0.6), props, 0.75, 1.15, true, _avoid)
	for k in range(first, chain.size()):
		debris(chain[k].pos, chain[k].r)
	_deco.clear()
	await get_tree().physics_frame
	for isl in _islands.slice(_islands.size() - (chain.size() - first)):
		if isl.grass != "":
			_grass(isl)
	_chunks.append([first, get_children().slice(before)])
	_prune()
	_extending = false


## Frees chunks far behind the player so an endless run never piles up.
func _prune() -> void:
	while _chunks.size() > 1 and int(_chunks[1][0]) < reached - 4:
		var old: Array = _chunks.pop_front()
		if int(old[0]) == 0:
			continue  # the start island stays (it holds the clouds, sky and weather nodes)
		for n in old[1]:
			if is_instance_valid(n):
				_floaters = _floaters.filter(func(f): return f[0] != n)
				n.queue_free()


func _mark_finish(n: Dictionary) -> void:
	var g := ground_pos(n.pos.x, n.pos.z, n.pos.y)
	_finish_mark = FX.beam(2.2, 300.0, Color(1.0, 0.82, 0.45), 1.2)
	_finish_mark.position = g
	add_child(_finish_mark)


# ------------------------------------------------------------ play

func on_start() -> void:
	await get_tree().create_timer(4.0).timeout
	if mode == "endless":
		session.first_hint("endless", "Fly as far as you can. Every island reached counts. %d falls and the run ends." % lives)
	else:
		session.first_hint("trial", "Reach the golden light at the end of the course. Gold: %s" % Levels.format_time(medals[0]))


func _physics_process(_dt: float) -> void:
	if session == null or session.player == null or _done:
		return
	var p := session.player
	if not p.is_on_floor():
		return
	var pos := p.global_position
	for k in range(reached + 1, mini(reached + 4, chain.size())):
		var n: Dictionary = chain[k]
		if Vector2(pos.x - n.pos.x, pos.z - n.pos.z).length() < float(n.r) + 1.0 and absf(pos.y - n.pos.y) < 6.0:
			reached = k
			session.checkpoint_pos = pos
			Sound.play("gate", -6.0, 1.0 + minf(k * 0.02, 0.6))
			if mode == "trial" and k == chain.size() - 1:
				_finish(true)
			elif mode == "endless" and k % 10 == 0:
				session.hud.hint("%d islands!" % k, 2.5)
			break
	if mode == "endless" and not _extending and reached >= chain.size() - 3:
		_extend()


## A fall (or a defeat) in a run. Endless: costs a life; trial: just costs time.
func on_fell() -> void:
	if mode != "endless" or _done:
		return
	lives -= 1
	session.hud.set_lives(lives)
	if lives <= 0:
		_finish(false)
	else:
		session.hud.hint("%d %s left" % [lives, "fall" if lives == 1 else "falls"], 2.5)


func _finish(won: bool) -> void:
	_done = true
	var t := session.elapsed
	var key := "endless" if mode == "endless" else "trial_%d" % level_id
	var rec: Dictionary = Progress.data["runs"].get(key, {})
	var result := {"mode": mode, "time": t, "islands": reached, "won": won, "medals": medals}
	if mode == "endless":
		result["new_best"] = reached > int(rec.get("best", 0))
		if result["new_best"]:
			rec["best"] = reached
	else:
		result["new_best"] = t < float(rec.get("best", INF))
		if result["new_best"]:
			rec["best"] = t
	result["best"] = rec.get("best", 0)
	Progress.data["runs"][key] = rec
	Progress.save()
	run_over.emit(result)


## Rows for the HUD's challenge panel.
func hud_rows() -> Array:
	var t := session.elapsed if session else 0.0
	if mode == "endless":
		var best := int(Progress.data["runs"].get("endless", {}).get("best", 0))
		return [["Endless flight", "open", true], ["Islands reached  %d" % reached, "open", false],
			["Best  %d" % best, "done" if reached > best and best > 0 else "open", false], ["Time  %s" % Levels.format_time(t), "open", false]]
	var names := ["Gold", "Silver", "Bronze"]
	var rows := [["%s  ·  %d / %d" % [title, reached, chain.size() - 1], "open", true]]
	for i in 3:
		rows.append(["%s  %s" % [names[i], Levels.format_time(medals[i])], "fail" if t > medals[i] else "open", false])
	return rows
