class_name LevelKit
extends LevelBase
## Route kit for building levels from "hops" between islands. Each hop derives the next island's
## position from glide physics (≈4.5 m forward per 1 m of sink, vents top out at ~0.95·height),
## so every route is reachable by construction. Subclasses set palette/props/sky and implement
## plan(), chaining hops from S and closing each route with finish().

const GLIDE := 4.5
const RADII := {"island_small_a": 5.0, "island_small_b": 4.5, "island_small_c": 5.5, "island_mid": 10.0,
	"island_flat": 11.0, "island_tall": 9.0, "island_east": 14.0, "island_long": 13.0, "island_big": 18.0,
	"island_hub": 24.0, "island_west": 15.0, "island_north": 12.0}

var palette := {}  # island material swaps, e.g. {"grass": "grass_sand", "rock": "rock_sand"}
var props := ["tree_a", "bush_a", "rock_a", "pine_a"]
var start_asset := "island_big"
var weather := ""  # "", "snow", "sand", "rain", "embers"
var S := {}
var _later: Array[Callable] = []
var _deco: Array = []  # nodes to decorate last
var _avoid: Array = []  # Vector3(x, z, radius) spots kept clear of decoration
var _route_angles: Array = []
var _vent_tops: Array = []
var _needs_sundial := false
var _hops := 0


func plan() -> void:
	pass


# ------------------------------------------------------------ build hooks

func islands() -> void:
	biome = palette.duplicate()
	spawn_point = Vector3(0, 1.5, 11)
	S = _node(start_asset, Vector3.ZERO, rng.randf() * TAU)
	_deco.erase(S)
	plan()
	par_time = 150.0 + 75.0 * _hops
	distant_islands(16, palette)


func layout() -> void:
	plaza_monolith(S.pos)
	_reserve(Vector3(0, 0, 11), 3.0)
	for c in _later:
		c.call()
	if _needs_sundial:
		var p := _free_spot(S, 13.0)
		sundial(p.x, p.z, S.pos.y)
		_reserve(p, 3.5)
	_auto_extras()
	_weather()
	scatter(S.pos, 12.0, S.r * 0.9, int(S.r * 0.6), props, 0.8, 1.2, true, _avoid)
	for n in _deco:
		scatter(n.pos, n.r * 0.35, n.r * 0.92, int(n.r * 0.6), props, 0.75, 1.15, true, _avoid)


# ------------------------------------------------------------ helpers

func _dir(ang: float) -> Vector3:
	return Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang)))


func _node(asset: String, pos: Vector3, yaw: float) -> Dictionary:
	var r: float = RADII[asset]
	var opts := palette.duplicate()
	opts["flowers"] = palette.is_empty()
	island(asset, pos, yaw, r, opts)
	var n := {"pos": pos, "r": r, "asset": asset}
	_deco.append(n)
	return n


func _reserve(p: Vector3, rad: float) -> void:
	_avoid.append(Vector3(p.x, p.z, rad))


func _ang_of(n: Dictionary) -> float:
	return rad_to_deg(atan2(n.pos.z - S.pos.z, n.pos.x - S.pos.x))


## A spot on island `n` at radius `rr` that's clear of reserved areas.
func _free_spot(n: Dictionary, rr: float) -> Vector3:
	for k in 24:
		var a := rng.randf() * TAU
		var p: Vector3 = n.pos + Vector3(cos(a) * rr, 0, sin(a) * rr)
		var ok := true
		for av in _avoid:
			if Vector2(p.x - av.x, p.z - av.y).length() < av.z + 2.5:
				ok = false
				break
		if ok:
			return p
	return n.pos + Vector3(rr, 0, 0)


# ------------------------------------------------------------ hops

## Glide down to a lower island.
func glide(cur: Dictionary, ang: float, drop: float, asset: String) -> Dictionary:
	_hops += 1
	_route_angles.append(ang)
	var rt: float = RADII[asset]
	var gap: float = max(7.0, 0.7 * GLIDE * (drop + 0.5))
	var p: Vector3 = cur.pos + _dir(ang) * (cur.r + gap + rt)
	p.y = cur.pos.y - drop
	return _node(asset, p, rng.randf() * TAU)


## Ride a vent up, then glide to a higher (or farther) island.
func vent(cur: Dictionary, ang: float, rise: float, asset: String) -> Dictionary:
	_hops += 1
	_route_angles.append(ang)
	var d := _dir(ang)
	var rt: float = RADII[asset]
	var h := rise + 14.0
	var vp: Vector3 = cur.pos + d * cur.r * 0.45
	var avail := 0.95 * h - rise
	var dist: float = max(0.62 * GLIDE * avail + rt, cur.r * 0.55 + rt + 6.0)
	var p := vp + d * dist
	p.y = cur.pos.y + rise
	var cy: float = cur.pos.y
	_reserve(vp, 6.0)
	_later.append(func(): updraft(vp.x, vp.z, cy, h))
	return _node(asset, p, rng.randf() * TAU)


## Launch pad into a chain of boost rings.
func rings(cur: Dictionary, ang: float, n: int, asset: String) -> Dictionary:
	_hops += 1
	_route_angles.append(ang)
	var d := _dir(ang)
	var rt: float = RADII[asset]
	var cy: float = cur.pos.y
	var padp: Vector3 = cur.pos + d * (cur.r - 3.0)
	_reserve(padp, 3.5)
	var pts: Array[Vector3] = []
	for i in n:
		var p: Vector3 = cur.pos + d * (cur.r + 17.0 + 38.0 * i)
		p.y = cy + 10.0 - 2.5 * i
		pts.append(p)
	var last: Vector3 = pts[-1]
	var tp: Vector3 = last + d * (40.0 + rt)
	tp.y = last.y - 7.0
	_later.append(_place_rings.bind(padp, cy, pts, d))
	return _node(asset, tp, rng.randf() * TAU)


func _place_rings(padp: Vector3, cy: float, pts: Array, d: Vector3) -> void:
	pad(padp.x, padp.z, cy)
	for p in pts:
		ring(p, p + d * 20.0)


## Stepping stones: "slab", "crumble", "melt", "night", "day" or "echo".
func stones(cur: Dictionary, ang: float, kind: String, n: int, rise_each: float, asset: String) -> Dictionary:
	_hops += 1
	_route_angles.append(ang)
	var d := _dir(ang)
	var rt: float = RADII[asset]
	var cy: float = cur.pos.y
	var pts: Array = []
	for i in n:
		var p: Vector3 = cur.pos + d * (cur.r + 3.5 + 6.5 * i)
		p.y = cy + 0.3 + rise_each * (i + 1)
		pts.append(p)
	var tp: Vector3 = pts[-1] + d * (2.2 + 3.0 + rt)
	tp.y = pts[-1].y
	if kind in ["night", "day"]:
		_needs_sundial = true
	var cpos: Vector3 = cur.pos + d * (cur.r - 3.0) + d.cross(Vector3.UP) * 3.0
	if kind == "echo":
		_reserve(cpos, 3.0)
	_later.append(_place_stones.bind(kind, pts, cpos))
	return _node(asset, tp, rng.randf() * TAU)


func _place_stones(kind: String, pts: Array, cpos: Vector3) -> void:
	match kind:
		"slab":
			for p in pts:
				slab(p)
		"crumble", "melt":
			for p in pts:
				crumble(p, "ice" if kind == "melt" else "crumble")
		"night", "day":
			for p in pts:
				phase(p, kind)
		"echo":
			echo_path(cpos, pts)


## Lever-turned causeway; `pulls` = how many lever pulls line it up (1 or 2).
func causeway(cur: Dictionary, ang: float, pulls: int, asset: String) -> Dictionary:
	_hops += 1
	_route_angles.append(ang)
	var d := _dir(ang)
	var rt: float = RADII[asset]
	var tp: Vector3 = cur.pos + d * (cur.r + 30.5 + 7.0 + rt)
	tp.y = cur.pos.y - 3.0
	var aligned := atan2(-d.z, d.x)
	var step := 90.0 / pulls
	var lp: Vector3 = cur.pos + d * (cur.r - 4.0) + d.cross(Vector3.UP) * 3.5
	_reserve(lp, 2.5)
	_reserve(cur.pos + d * (cur.r - 1.0), 3.0)
	var c: Vector3 = cur.pos
	var cy: float = cur.pos.y
	_later.append(func():
		var t := turning(causeway_pivot(c, d), rad_to_deg(aligned) + 90.0, step)
		lever(lp.x, lp.z, cy, [t]))
	return _node(asset, tp, rng.randf() * TAU)


## Ferry stone across a wide gap at the same height.
func ferry(cur: Dictionary, ang: float, asset: String) -> Dictionary:
	_hops += 1
	_route_angles.append(ang)
	var d := _dir(ang)
	var rt: float = RADII[asset]
	var tp: Vector3 = cur.pos + d * (cur.r + 34.0 + rt)
	tp.y = cur.pos.y
	var c: Vector3 = cur.pos
	_later.append(func():
		var a := rim(c, d) + d * 2.8 + Vector3(0, -0.35, 0)
		var b := rim(tp, -d) - d * 2.8
		b.y = a.y
		mover(a, b, 8.0))
	return _node(asset, tp, rng.randf() * TAU)


## Elevator stone straight up beside the next island.
func elevator(cur: Dictionary, ang: float, rise: float, asset: String) -> Dictionary:
	_hops += 1
	_route_angles.append(ang)
	var d := _dir(ang)
	var rt: float = RADII[asset]
	var tp: Vector3 = cur.pos + d * (cur.r + 2.8 + 2.2 + 1.2 + rt)
	tp.y = cur.pos.y + rise
	var c: Vector3 = cur.pos
	_later.append(func():
		var a := rim(c, d) + d * 2.8 + Vector3(0, -0.35, 0)
		mover(a, Vector3(a.x, tp.y - 0.3, a.z), 6.0))
	return _node(asset, tp, rng.randf() * TAU)


## A ring of orbiting stones around a small islet; hop on, ride, hop in.
func carousel_hop(cur: Dictionary, ang: float) -> Dictionary:
	_hops += 1
	_route_angles.append(ang)
	var d := _dir(ang)
	var tp: Vector3 = cur.pos + d * (cur.r + 3.0 + 12.0)
	tp.y = cur.pos.y
	_later.append(func(): carousel(tp + Vector3(0, -0.4, 0), 12.0, 4, 20.0))
	return _node("island_small_b", tp, rng.randf() * TAU)


# ------------------------------------------------------------ route ends

## Shard (optionally sealed), enemies, and a return vent sized to glide home to S.
## puzzle: "free", "plates", "bells", "mirror"
func finish(n: Dictionary, puzzle := "free", wisps := 0, sentinels := 0) -> void:
	var d := _dir(_ang_of(n))
	var side := d.cross(Vector3.UP)
	var c: Vector3 = n.pos
	var r: float = n.r
	var vp: Vector3 = c + d * r * 0.45 + side * r * 0.2
	var back: float = Vector2(c.x - S.pos.x, c.z - S.pos.z).length() - S.r - r
	var need_top: float = S.pos.y + back / (0.75 * GLIDE) + 3.0
	var h: float = max(18.0, (need_top - c.y) / 0.95 + 2.0)
	_vent_tops.append(Vector3(vp.x, c.y + h * 0.9, vp.z) + side * 7.0)
	_reserve(vp, 6.0)
	_reserve(c, 10.0 if puzzle == "mirror" else 6.5)
	assert(puzzle not in ["mirror", "plates"] or r >= 9.0, "mirror/plate puzzles need an island of radius >= 9")
	_deco.erase(n)
	_deco.append(n)
	_later.append(_finish_now.bind(n, puzzle, wisps, sentinels, d, side, c, r, vp, h))


func _finish_now(n: Dictionary, puzzle: String, wisps: int, sentinels: int, d: Vector3, side: Vector3, c: Vector3, r: float, vp: Vector3, h: float) -> void:
	var shard := shrine_shard(c.x - side.x * 1.5, c.z - side.z * 1.5, c.y)
	match puzzle:
		"plates":
			var p1 := plate(c.x - side.x * 4.5 - d.x * 3.0, c.z - side.z * 4.5 - d.z * 3.0, c.y)
			var p2 := plate(c.x + side.x * 3.0 - d.x * 3.5, c.z + side.z * 3.0 - d.z * 3.5, c.y)
			stone(c.x - d.x * 6.0, c.z - d.z * 6.0, c.y)
			cage(shard, [p1, p2])
		"bells":
			cage(shard, [bell(c.x + side.x * 4.5, c.z + side.z * 4.5, c.y, 0.4), bell(c.x - side.x * 5.5 - d.x * 2.0, c.z - side.z * 5.5 - d.z * 2.0, c.y, 2.0)])
		"mirror":
			var e := c - side * 5.0 - d * 4.5
			emitter(e.x, e.z, c.y, e + side * 10.0)
			var m1 := c + side * 4.5 - d * 4.5
			var base := atan2(-d.z, d.x)
			mirror(m1.x, m1.z, c.y, 0, base)
			var m2 := c + side * 4.5 + d * 4.5
			mirror(m2.x, m2.z, c.y, 2, base)
			var rv := c - side * 5.0 + d * 4.5
			cage(shard, [receiver(rv.x, rv.z, c.y)])
	for i in wisps:
		wisp(c + Vector3(0, 3.0 + i, 0) + side * (i * 3.0), r * 0.6)
	for i in sentinels:
		var sp := c - d * (r - 2.0) + side * (r * 0.5 * (1 if i % 2 == 0 else -1))
		sentinel(sp.x, sp.z, c.y)
	updraft(vp.x, vp.z, c.y, h)


# ------------------------------------------------------------ automatic optional content

func _auto_extras() -> void:
	# Secret islet in the widest gap between routes, reached by a mushroom bounce.
	var best := 90.0
	var best_gap := -1.0
	var angs: Array = _route_angles.duplicate()
	angs.sort()
	if angs.is_empty():
		angs = [0.0]
	for i in angs.size():
		var a: float = angs[i]
		var b: float = angs[(i + 1) % angs.size()] + (360.0 if i == angs.size() - 1 else 0.0)
		if b - a > best_gap:
			best_gap = b - a
			best = (a + b) * 0.5
	var sp: Vector3 = S.pos + _dir(best) * (S.r + 22.0 + 4.5)
	sp.y = S.pos.y - 6.0
	_place_secret(sp)
	var m := _free_spot(S, 13.5)
	mushroom_fragment(m.x, m.z, S.pos.y)
	_reserve(m, 3.0)
	if not _vent_tops.is_empty():
		fragment(_vent_tops[0])
	var bs := []
	for k in 3:
		var bp := _free_spot(S, 14.5)
		_reserve(bp, 3.0)
		bs.append(bell(bp.x, bp.z, S.pos.y, rng.randf() * TAU))
	var cp := _free_spot(S, 12.5)
	_reserve(cp, 3.0)
	cage(fragment(ground_pos(cp.x, cp.z, S.pos.y) + Vector3.UP * 1.3), bs)


## Secret islets must exist before physics; this level kind adds it during layout, so spawn
## the island now and place its contents after the physics world has it.
func _place_secret(p: Vector3) -> void:
	var opts := palette.duplicate()
	opts["flowers"] = palette.is_empty()
	var n := Assets.spawn("island_small_b", true, 1, true, {"grass": opts.get("grass", "grass"), "rock": opts.get("rock", "rock")})
	n.position = p
	add_child(n)
	_islands.append({"pos": p, "r": 4.5, "grass": opts.get("grass", "grass"), "flowers": opts["flowers"]})
	secret_route(S.pos, p)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var g := ground_pos(p.x, p.z, p.y)
	put("pillar_broken_b", p.x - 1.5, p.z + 1.5, p.y, rng.randf() * TAU)
	fragment(g + Vector3(1.5, 1.2, -1.0))
	updraft(p.x + 1.8, p.z + 1.5, p.y, 26.0)
	fragment(g + Vector3(1.8 + 7.0, 23.0, 1.5))
	var c := Constellation.new()
	c.azimuth = atan2(p.x - spawn_point.x, p.z - spawn_point.z)
	add_child(c)


func _weather() -> void:
	var holder := Node3D.new()
	match weather:
		"snow":
			holder.add_child(FX.snow([400, 700, 1100, 1500][Settings.quality()]))
		"sand":
			holder.add_child(FX.sand([300, 500, 800, 1100][Settings.quality()]))
		"rain":
			holder.add_child(FX.rain([500, 900, 1400, 2000][Settings.quality()]))
		"embers":
			var e := FX.lanterns(Vector3(30, 10, 30), Color(1.0, 0.45, 0.15, 0.9), 120)
			(e.process_material as ParticleProcessMaterial).gravity = Vector3(0, 0.6, 0)
			holder.add_child(e)
		_:
			return
	follow_fx(holder)
