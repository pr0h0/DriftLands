class_name RunLevel
extends LevelKit
## Separate modes outside the campaign, built from the route kit:
##   "endless": an island chain that keeps generating ahead of you; lives run out on falls.
##   "trial":   a fixed course of hops against the clock, with medal times.

signal run_over(result: Dictionary)

## Endless biome stretches: [name, island palette, props]. A new one every STRETCH islands.
const BIOMES := [
	["Green Meadows", {}, ["tree_a", "bush_a", "rock_a", "pine_a", "tree_blossom"]],
	["Blossom Drift", {"grass": "grass_gold"}, ["tree_blossom", "tree_a", "bush_flower", "rock_b"]],
	["Autumn Isles", {}, ["tree_autumn", "tree_autumn_b", "bush_flower", "rock_a"]],
	["Frost Reaches", {"grass": "grass_snow", "rock": "rock_ice"}, ["pine_a", "pine_b", "ice_spire", "rock_c"]],
	["Sunken Sands", {"grass": "grass_sand", "rock": "rock_sand"}, ["dead_tree", "rock_a", "pillar_broken_a", "rock_c"]],
	["Crystal Shelf", {"grass": "grass_crystal", "rock": "rock_crystal"}, ["crystals_a", "crystals_b", "dead_tree", "rock_c"]],
	["Ashen Rise", {"grass": "grass_ash", "rock": "rock_ash"}, ["dead_tree", "rock_a", "rock_c", "pillar_broken_a"]],
	["Storm Shelf", {"grass": "grass_storm", "rock": "rock_dark"}, ["pine_a", "pine_b", "rock_c", "rock_a"]],
]
const STRETCH := 8
const RUINS := ["arch", "arch_broken", "pillar_broken_a", "pillar_broken_b", "pillar_fallen"]

var mode := "endless"
var seed_value := 1
var trial_hops := 8
var lives := 3
var gold := 0.0  # trials: fixed gold time (s); silver and bronze keep the old ratios to it
var _biome := 0
var _biome_deck: Array = []
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
		scatter(n.pos, n.r * 0.35 if n != S else 12.0, n.r * 0.92, int(n.r * 0.6), n.get("props", props), 0.75, 1.15, true, _avoid)
	_deco.clear()
	if mode == "trial":
		_mark_finish(chain[-1])
	_chunks.append([0, get_children()])


# ------------------------------------------------------------ route generation

## Adds one hop to the chain; harder kinds and enemies unlock further along.
func _hop() -> void:
	var cur: Dictionary = chain[-1]
	var i := chain.size()
	if mode == "endless":
		_endless_hop(cur, i)
		return
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
		var g := gold if gold > 0.0 else _estimate * 1.15
		medals = [g, g * 1.3, g * 1.75]


## Endless: biome stretches, a wider pool of hops as you go, a ruins rest island every
## tenth, and enemies that guard the gaps as well as the islands. (Trials keep _hop's
## original generation so their courses and medal times never change.)
func _endless_hop(cur: Dictionary, i: int) -> void:
	if i > 1 and (i - 1) % STRETCH == 0:
		if _biome_deck.is_empty():  # every biome once before any repeats
			_biome_deck = range(BIOMES.size())
			_biome_deck.erase(_biome)
			for j in range(_biome_deck.size() - 1, 0, -1):
				var r := rng.randi() % (j + 1)
				var t = _biome_deck[j]
				_biome_deck[j] = _biome_deck[r]
				_biome_deck[r] = t
		_biome = _biome_deck.pop_back()
		palette = (BIOMES[_biome][1] as Dictionary).duplicate()
		props = BIOMES[_biome][2]
		var bname: String = BIOMES[_biome][0]
		_later.append(func(): if session and session.hud: session.hud.hint("Entering the %s" % bname, 3.5))
	var frost := _biome == 3
	_heading = clampf(_heading + rng.randf_range(-32.0, 32.0), _base_heading - 60.0, _base_heading + 60.0)
	var a := _heading
	var small := ["island_small_a", "island_small_b", "island_small_c"]
	var mid := ["island_mid", "island_flat", "island_tall"]
	var asset: String = (small if rng.randf() < 0.4 else mid)[rng.randi() % 3]
	var rest := i % 10 == 0
	if rest:
		asset = ["island_big", "island_east", "island_long"][rng.randi() % 3]
	var kinds := ["glide", "vent", "slab", "mushroom"]
	if i >= 3:
		kinds += ["zigzag", "rings", "ferry"]
	if i >= 6:
		kinds += ["crumble", "elevator", "gust", "echo"]
	if i >= 12:
		kinds += ["carousel", "causeway", "gust", "zigzag", "crumble"]
	# Drift back toward a comfortable height: half the time pick a hop that goes the right way.
	var y: float = cur.pos.y
	if y > 24.0 and rng.randf() < 0.5:
		kinds = ["glide", "gust"]
	elif y < -10.0 and rng.randf() < 0.5:
		kinds = ["vent", "elevator", "mushroom"]
	var k: String = kinds[rng.randi() % kinds.size()]
	if k in ["carousel", "causeway"] and rest:
		k = "glide"
	var nxt: Dictionary
	match k:
		"glide", "gust":
			var drop := rng.randf_range(3.0, 7.0)
			nxt = glide(cur, a, drop, asset)
			if k == "gust":
				_gust_gap(cur, nxt)
		"vent":
			nxt = vent(cur, a, rng.randf_range(8.0, 14.0), asset)
		"mushroom":
			nxt = _mushroom_hop(cur, a, asset)
		"slab", "crumble":
			var kind := k
			if k == "crumble" and frost:
				kind = "melt"
			nxt = stones(cur, a, kind, rng.randi_range(3, 5), rng.randf_range(0.2, 0.8), asset)
		"echo":
			nxt = stones(cur, a, "echo", rng.randi_range(3, 4), rng.randf_range(0.0, 0.5), asset)
		"zigzag":
			nxt = _zigzag_hop(cur, a, asset)
		"rings":
			nxt = rings(cur, a, rng.randi_range(2, 3), mid[rng.randi() % 3])
		"ferry":
			nxt = ferry(cur, a, asset)
		"elevator":
			nxt = elevator(cur, a, rng.randf_range(8.0, 14.0), asset)
		"carousel":
			nxt = carousel_hop(cur, a)
		"causeway":
			nxt = causeway(cur, a, 1 + int(i >= 20 and rng.randf() < 0.5), mid[rng.randi() % 3])
	nxt["props"] = props
	nxt["kind"] = k
	nxt["biome"] = _biome
	if rest:
		_ruins(nxt)
	_enemies(cur, nxt, i, k, rest)
	nxt["index"] = i
	chain.append(nxt)


## Bounce cap near the rim springs you up to a higher island a short glide away.
func _mushroom_hop(cur: Dictionary, a: float, asset: String) -> Dictionary:
	_hops += 1
	_route_angles.append(a)
	var d := _dir(a)
	var rt: float = RADII[asset]
	var mp: Vector3 = cur.pos + d * (cur.r - 2.6)
	_reserve(mp, 2.5)
	var tp: Vector3 = cur.pos + d * (cur.r + 9.0 + rt)
	tp.y = cur.pos.y + rng.randf_range(2.5, 4.5)
	var cy: float = cur.pos.y
	_later.append(func(): mushroom(mp.x, mp.z, cy))
	return _node(asset, tp, rng.randf() * TAU)


## Stepping stones that weave left and right of the straight line.
func _zigzag_hop(cur: Dictionary, a: float, asset: String) -> Dictionary:
	_hops += 1
	_route_angles.append(a)
	var d := _dir(a)
	var side := d.cross(Vector3.UP)
	var rt: float = RADII[asset]
	var n := rng.randi_range(4, 6)
	var pts: Array = []
	for j in n:
		var p: Vector3 = cur.pos + d * (cur.r + 3.0 + 4.2 * j) + side * (2.0 if j % 2 == 0 else -2.0)
		p.y = cur.pos.y + 0.3 + 0.35 * j
		pts.append(p)
	var tp: Vector3 = cur.pos + d * (cur.r + 3.0 + 4.2 * (n - 1) + 5.0 + rt)
	tp.y = pts[-1].y
	_later.append(func():
		for p in pts:
			slab(p, 0.85))
	return _node(asset, tp, rng.randf() * TAU)


## A crosswind that pulses across the middle of a glide gap.
func _gust_gap(cur: Dictionary, nxt: Dictionary) -> void:
	var a: Vector3 = cur.pos
	var b: Vector3 = nxt.pos
	var d := (b - a).slide(Vector3.UP).normalized()
	var mid := a.lerp(b, 0.5) + Vector3(0, 1.5, 0)
	var across := d.cross(Vector3.UP) * (1.0 if rng.randf() < 0.5 else -1.0)
	var w := clampf((b - a).slide(Vector3.UP).length() - float(cur.r) - float(nxt.r), 8.0, 14.0) * 0.7
	_later.append(func(): gust(mid, Vector3(w, 12.0, w), across, 6.0, 6.0, 3.0))


## A broken arch and pillars on the rest islands.
func _ruins(n: Dictionary) -> void:
	var c: Vector3 = n.pos
	var r: float = n.r
	var yaw := rng.randf() * TAU
	var picks: Array = []
	for j in 4:
		picks.append([RUINS[rng.randi() % RUINS.size()], yaw + j * TAU / 4.0 + rng.randf_range(-0.4, 0.4), rng.randf_range(0.45, 0.7)])
	_later.append(func():
		for pk in picks:
			var p := c + Vector3(cos(pk[1]), 0, sin(pk[1])) * r * float(pk[2])
			put(pk[0], p.x, p.z, c.y, pk[1] + PI / 2.0)
			_reserve(p, 2.5))


## Wisps on islands and in the gaps between them, pairs later on, sentinels on big islands.
func _enemies(cur: Dictionary, nxt: Dictionary, i: int, k: String, rest: bool) -> void:
	if rest or i < 5:
		return
	var c: Vector3 = nxt.pos
	var rr: float = nxt.r
	var heat := minf(i * 0.012, 0.3)
	if rng.randf() < 0.25 + heat:
		var count := 2 if i >= 14 and rng.randf() < 0.4 else 1
		for j in count:
			var off := Vector3(rng.randf_range(-2.0, 2.0), 3.0 + j * 1.5, rng.randf_range(-2.0, 2.0))
			_later.append(func(): wisp(c + off, rr * 0.6))
	if i >= 9 and k in ["glide", "gust", "rings"] and rng.randf() < 0.2 + heat:
		var gap: Vector3 = (cur.pos as Vector3).lerp(c, 0.5) + Vector3(0, 1.0, 0)
		_later.append(func(): wisp(gap, 4.0))
	if i >= 10 and rr >= 9.0 and rng.randf() < 0.3 + heat:
		var off2 := Vector3(rng.randf_range(-3.0, 3.0), 0, rng.randf_range(-3.0, 3.0))
		_later.append(func(): sentinel(c.x + off2.x, c.z + off2.z, c.y))


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
		scatter(n.pos, n.r * 0.35, n.r * 0.92, int(n.r * 0.6), n.get("props", props), 0.75, 1.15, true, _avoid)
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
	var had := Cosmetics.unlocked_names()
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
	result["unlocks"] = Cosmetics.unlocked_names().filter(func(n): return not n in had)
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
