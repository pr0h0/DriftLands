class_name LevelBase
extends Node3D
## Shared level toolkit. Subclasses override `islands()` (terrain first, so later placement can
## raycast onto it) and `layout()` (props, mechanics, enemies), plus optional hooks.

var level_id := 1
var title := "Level"
var subtitle := ""
var mood := "dawn"
var sky := {"hour": 17.3}
var kill_y := -60.0
var spawn_point := Vector3(0, 2, 10)
var spawn_yaw := 0.0
var decor_only := false

var cycle: SkyCycle
var session: Session
var follow: Node3D
var shards: Array[Shard] = []
var fragments: Array[Fragment] = []
var monolith: Node3D
var par_time := 360.0
var _dormant: Array = []  # [MeshInstance3D crystal, OmniLight3D]

var _clouds: Array[Node3D] = []
var _floaters: Array = []  # [node, base_y, phase, spin]
var _islands: Array = []  # {pos, r, grass, flowers}
var _followers: Array[Node3D] = []  # effects that track the player (rain, motes)
var rng := RandomNumberGenerator.new()
var prop_overrides := {}
var biome := {}
## When true, generic props are swapped for Quaternius nature models (see NATURE).
var nature := false
## Chapter finale: once the beacon wakes, the island collapses and you must escape in time.
var escape := false
var escape_time := 75.0
var _wisps := 0
var _sentinels := 0
const NATURE := {
	"tree_a": ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5"],
	"tree_b": ["CommonTree_2", "CommonTree_4", "TwistedTree_2"],
	"pine_a": ["Pine_1", "Pine_2", "Pine_3"],
	"pine_b": ["Pine_4", "Pine_5"],
	"dead_tree": ["DeadTree_1", "DeadTree_2", "DeadTree_3"],
	"bush_a": ["Bush_Common"],
	"bush_b": ["Bush_Common", "Fern_1"],
	"bush_flower": ["Bush_Common_Flowers"],
	"rock_a": ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"],
	"rock_b": ["Rock_Medium_2", "Rock_Medium_3"],
	"rock_c": ["Rock_Medium_1"],
}
const FLORA := ["Fern_1", "Plant_1", "Plant_7", "Flower_3_Group", "Flower_4_Group", "Mushroom_Common", "Mushroom_Laetiporus",
	"Clover_1", "Grass_Common_Tall", "Pebble_Round_1", "Pebble_Round_3", "Pebble_Square_2"]  # island material swaps used for secret islets (e.g. {"grass": "grass_sand", "rock": "rock_sand"})  # biome material swaps for props (e.g. {"leaf": "leaf_snow"})


# ------------------------------------------------------------ overridables

func islands() -> void:
	pass


func layout() -> void:
	pass


func on_start() -> void:
	pass


func on_finale() -> void:
	pass


# ------------------------------------------------------------ build

func build() -> void:
	rng.seed = 1000 + level_id
	_make_clouds()
	islands()
	await get_tree().physics_frame
	await get_tree().physics_frame
	layout()
	_place_secrets()
	if not _secrets.is_empty():
		var c := Constellation.new()
		var target: Vector3 = _secrets[0][0]
		c.azimuth = atan2(target.x - spawn_point.x, target.z - spawn_point.z)
		add_child(c)
	for isl in _islands:
		debris(isl.pos, isl.r)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for isl in _islands:
		if isl.grass != "":
			_grass(isl)
			if nature and isl.grass == "grass":
				_flora(isl)


func island(asset: String, pos: Vector3, yaw: float, r: float, opts := {}) -> Node3D:
	var overrides := {"grass": opts.get("grass", "grass")}
	if opts.has("rock"):
		overrides["rock"] = opts["rock"]
	var n := Assets.spawn(asset, true, 1, true, overrides)
	if opts.get("ice", false):
		for b in n.find_children("*", "StaticBody3D", true, false):
			b.set_meta("ice", true)
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			for i in (mi as MeshInstance3D).mesh.get_surface_count():
				if (mi as MeshInstance3D).mesh.surface_get_material(i).resource_name == "grass":
					mi.set_surface_override_material(i, Mats.get_mat("ice"))
	var s: float = opts.get("scale", 1.0)
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * s
	add_child(n)
	_islands.append({"pos": pos, "r": r, "grass": "" if opts.get("no_grass", false) else overrides["grass"],
		"flowers": opts.get("flowers", false)})
	return n


func ground(x: float, z: float, from_y: float, mask := 1) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, from_y - 80.0, z), mask)
	return get_world_3d().direct_space_state.intersect_ray(q)


func ground_pos(x: float, z: float, near_y: float) -> Vector3:
	var hit := ground(x, z, near_y + 25.0)
	return Vector3(x, near_y, z) if hit.is_empty() else hit.position


## Last solid ground walking from `c` along horizontal `dir` (finds an island's edge).
func rim(c: Vector3, dir: Vector3, inset := 0.0) -> Vector3:
	var d := dir.normalized()
	var last := ground_pos(c.x, c.z, c.y)
	var dist := 0.0
	while dist < 120.0:
		dist += 0.5
		var p := c + d * dist
		var hit := ground(p.x, p.z, c.y + 25.0)
		if hit.is_empty() or hit.position.y < c.y - 6.0:
			break
		last = hit.position
	return last - d * inset


## Places an asset on the terrain under (x, z). `near_y` is roughly the island height.
func put(asset: String, x: float, z: float, near_y: float, yaw := 0.0, s := 1.0, sink := 0.08, collide := true) -> Node3D:
	var hit := ground(x, z, near_y + 25.0)
	if hit.is_empty():
		return null
	if nature and NATURE.has(asset):
		var pool: Array = NATURE[asset]
		asset = "nature/" + pool[rng.randi() % pool.size()]
		s *= 0.85
	var n := Assets.spawn(asset, collide, 2, false, prop_overrides)
	n.position = hit.position - Vector3(0, sink * s, 0)
	n.rotation.y = yaw
	n.scale = Vector3.ONE * s
	add_child(n)
	return n


func polar(c: Vector3, ang: float, r: float) -> Vector2:
	return Vector2(c.x + cos(ang) * r, c.z + sin(ang) * r)


func scatter(center: Vector3, r_min: float, r_max: float, count: int, assets: Array, s_min := 0.8, s_max := 1.2, collide := true, avoid := []) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 8:
		tries += 1
		var p := polar(center, rng.randf() * TAU, lerpf(r_min, r_max, sqrt(rng.randf())))
		var ok := true
		for av in avoid:
			if Vector2(p.x - av.x, p.y - av.y).length() < av.z:
				ok = false
				break
		if ok and put(assets[rng.randi() % assets.size()], p.x, p.y, center.y, rng.randf() * TAU, rng.randf_range(s_min, s_max), 0.1, collide):
			placed += 1


func _add(n: Node3D, pos := Vector3.INF) -> Node3D:
	add_child(n)
	if pos != Vector3.INF:
		n.global_position = pos
	return n


# ------------------------------------------------------------ goal + shards

func plaza_monolith(c: Vector3, yaw := PI / 4) -> void:
	var y := ground_pos(c.x, c.z, c.y).y + 0.06
	var plaza := Assets.spawn("plaza", true, 2)
	plaza.position = Vector3(c.x, y, c.z)
	add_child(plaza)
	monolith = Assets.spawn("monolith", true, 2)
	monolith.position = Vector3(c.x, y, c.z)
	monolith.rotation.y = yaw
	add_child(monolith)
	# Dormant lights around the plaza wake up when the beacon is lit.
	for i in 6:
		var a := i * TAU / 6.0 + 0.26
		var p := Vector3(c.x + cos(a) * 10.4, 0, c.z + sin(a) * 10.4)
		var g := ground_pos(p.x, p.z, c.y)
		var post := Assets.spawn("cairn", true, 2)
		post.position = g
		post.scale = Vector3.ONE * 0.8
		add_child(post)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.5)
		l.omni_range = 9.0
		l.light_energy = 0.0
		l.position = g + Vector3.UP * 2.0
		add_child(l)
		_dormant.append([post, l])


func shard_at(pos: Vector3) -> Shard:
	var s := Shard.new()
	s.position = pos
	add_child(s)
	shards.append(s)
	return s


func shrine_shard(x: float, z: float, near_y: float, yaw := 0.0) -> Shard:
	var shrine := put("shrine", x, z, near_y, yaw, 1.0, 0.05)
	return shard_at((shrine.position if shrine else Vector3(x, near_y, z)) + Vector3(0, 2.0, 0))


func fragment(pos: Vector3) -> Fragment:
	var f := Fragment.new()
	f.position = pos
	add_child(f)
	fragments.append(f)
	return f


func mushroom(x: float, z: float, near_y: float) -> Mushroom:
	var m := Mushroom.new()
	m.position = ground_pos(x, z, near_y) - Vector3(0, 0.1, 0)
	m.rotation.y = rng.randf() * TAU
	add_child(m)
	return m


## A bounce cap with a fragment floating high above it.
func mushroom_fragment(x: float, z: float, near_y: float) -> void:
	var m := mushroom(x, z, near_y)
	fragment(m.position + Vector3.UP * 6.6)


func bell(x: float, z: float, near_y: float, yaw := 0.0) -> Bell:
	var b := Bell.new()
	b.position = ground_pos(x, z, near_y)
	b.rotation.y = yaw
	add_child(b)
	return b


func prism(x: float, z: float, near_y: float) -> Prism:
	var p := Prism.new()
	p.position = ground_pos(x, z, near_y)
	add_child(p)
	return p


## Echo crystal at `at` summoning stones along `points` (they light up in order).
func echo_path(at: Vector3, points: Array) -> EchoCrystal:
	var e := EchoCrystal.new()
	e.position = ground_pos(at.x, at.z, at.y)
	for p in points:
		var st := PhasePlatform.new()
		st.phase = "manual"
		st.position = p
		st.rotation.y = rng.randf() * TAU
		add_child(st)
		e.stones.append(st)
	add_child(e)
	return e


## Evenly spaced stone positions bridging the edge of island `a` to the edge of island `b`.
func stones_between(a: Vector3, b: Vector3, spacing := 5.8) -> Array:
	var d := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var p0 := rim(a, d) + d * 2.6
	var p1 := rim(b, -d) - d * 2.6
	var n := maxi(1, int(round(p0.distance_to(p1) / spacing)) + 1)
	var out := []
	for i in n:
		var t: float = float(i) / maxf(n - 1, 1)
		var p := p0.lerp(p1, t)
		p.y = lerp(p0.y, p1.y, t) - 0.25
		out.append(p)
	return out


## A bounce cap on island `from`'s edge aimed at `to` (the way to a secret islet).
func secret_route(from: Vector3, to: Vector3) -> void:
	var d := Vector3(to.x - from.x, 0, to.z - from.z).normalized()
	var p := rim(from, d, 3.0)
	mushroom(p.x, p.z, from.y)


## Optional secret islet with a return updraft and two fragments (one on the ground, one atop the updraft).
func secret_island(asset: String, c: Vector3, r: float) -> void:
	var opts := biome.duplicate()
	opts["flowers"] = biome.is_empty()
	island(asset, c, rng.randf() * TAU, r, opts)
	_secrets.append([c, r])


var _secrets: Array = []


func _place_secrets() -> void:
	for sc in _secrets:
		var c: Vector3 = sc[0]
		var g := ground_pos(c.x, c.z, c.y)
		put("pillar_broken_b", c.x - 1.5, c.z + 1.5, c.y, rng.randf() * TAU)
		fragment(g + Vector3(1.5, 1.2, -1.0))
		updraft(c.x + 1.8, c.z + 1.5, c.y, 26.0)
		fragment(g + Vector3(1.8 + 7.0, 23.0, 1.5))


## Lights the first `n` dormant posts around the plaza (title island progress).
func wake_posts(n: int) -> void:
	for i in min(n, _dormant.size()):
		var d: Array = _dormant[i]
		(d[1] as OmniLight3D).light_energy = 2.2
		(ElUtil.unique_mat(d[0], "rune") as StandardMaterial3D).emission_energy_multiplier = 6.0


## Lights one of the monolith's three rune bands (0-2).
func light_runes(band: int) -> void:
	var runes := Assets.find(monolith, "Runes%d" % (band + 1)) as MeshInstance3D
	if runes:
		var m := (Mats.get_mat("rune") as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.emission_energy_multiplier = 5.0
		runes.material_override = m


## World reaction when the beacon is lit: dormant lights wake, flowers bloom, life returns.
func celebrate() -> void:
	for i in _dormant.size():
		var d: Array = _dormant[i]
		var t := create_tween()
		t.tween_interval(0.6 + i * 0.35)
		t.tween_property(d[1], "light_energy", 2.2, 1.2)
		var rune := ElUtil.unique_mat(d[0], "rune") as StandardMaterial3D
		var t2 := create_tween()
		t2.tween_interval(0.6 + i * 0.35)
		t2.tween_property(rune, "emission_energy_multiplier", 6.0, 1.2)
	if monolith:
		var c := monolith.global_position
		var bloom := FX.lanterns(Vector3(16, 3, 16), Color(1.0, 0.85, 0.55, 0.9), 60)
		bloom.position = c + Vector3(0, 3, 0)
		add_child(bloom)
		var bf := FX.butterflies(Vector3(12, 1.5, 12))
		bf.position = c + Vector3(0, 2, 0)
		add_child(bf)
		var b := Birds.new()
		b.center = c + Vector3(0, 22, 0)
		b.count = 12
		b.radius = 30.0
		add_child(b)
		_bloom_flowers(c)


func _bloom_flowers(c: Vector3) -> void:
	var xf: Array[Transform3D] = []
	var col: Array[Color] = []
	var palette := [Color(1, 1, 0.95), Color(1.0, 0.85, 0.3), Color(1.0, 0.6, 0.75), Color(0.75, 0.65, 1.0)]
	for i in 900:
		var a := rng.randf() * TAU
		var d := rng.randf_range(10.0, 22.0)
		var hit := ground(c.x + cos(a) * d, c.z + sin(a) * d, c.y + 15.0, 1 | 2)
		if hit.is_empty() or not hit.collider.has_meta("terrain") or hit.normal.y < 0.8:
			continue
		xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), hit.position))
		col.append(palette[rng.randi() % palette.size()])
	if xf.is_empty():
		return
	var mat := (Mats.get_mat("flowers") as ShaderMaterial).duplicate() as ShaderMaterial
	mat.set_shader_parameter("grow", 0.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _blade_mesh(true)
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, col[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	create_tween().tween_method(func(v): mat.set_shader_parameter("grow", v), 0.0, 1.0, 4.0).set_delay(1.0).set_trans(Tween.TRANS_SINE)


func cage(shard: Node3D, switches: Array) -> ShardCage:
	var c := ShardCage.new()
	c.shard = shard
	c.switches = switches
	c.position = shard.position
	add_child(c)
	return c


# ------------------------------------------------------------ traversal

func updraft(x: float, z: float, near_y: float, h: float) -> Updraft:
	return updraft_at(ground_pos(x, z, near_y), h)


func updraft_at(base: Vector3, h: float) -> Updraft:
	var u := Updraft.new().setup(h)
	u.position = base
	add_child(u)
	return u


func ring(pos: Vector3, toward: Vector3, power := 26.0) -> BoostRing:
	var r := BoostRing.new()
	r.power = power
	r.transform = Transform3D(Basis.looking_at((toward - pos).normalized(), Vector3.UP), pos)
	add_child(r)
	return r


func pad(x: float, z: float, near_y: float, power := 21.0) -> LaunchPad:
	var p := LaunchPad.new()
	p.power = power
	p.position = ground_pos(x, z, near_y) - Vector3(0, 0.05, 0)
	add_child(p)
	return p


func phase(pos: Vector3, kind: String, s := 1.0) -> PhasePlatform:
	var p := PhasePlatform.new()
	p.phase = kind
	p.position = pos
	p.rotation.y = rng.randf() * TAU
	p.scale = Vector3.ONE * s
	add_child(p)
	return p


## A light bridge stone: solid only while every switch is on.
func bridge(pos: Vector3, switches: Array) -> PhasePlatform:
	var p := PhasePlatform.new()
	p.phase = "switch"
	p.switches = switches
	p.position = pos
	p.rotation.y = rng.randf() * TAU
	add_child(p)
	return p


## Pivot position for a causeway (arms 16 m) whose tip overlaps island `c`'s edge by ~1.5 m
## when it lines up along `dir`.
func causeway_pivot(c: Vector3, dir: Vector3) -> Vector3:
	var r := rim(c, dir)
	return r + dir.normalized() * 14.5 + Vector3(0, -0.05, 0)


## A structure on a pivot that turns `step` degrees per lever pull.
func turning(pos: Vector3, yaw_deg: float, step := 90.0, asset := "causeway") -> Turning:
	var t := Turning.new()
	t.asset = asset
	t.step = step
	t.position = pos
	t.rotation.y = deg_to_rad(yaw_deg)
	add_child(t)
	return t


## A lever riding on a Turning structure (local position on its deck).
func lever_on(host: Turning, local: Vector3, targets: Array) -> Lever:
	var l := Lever.new()
	l.targets = targets
	l.solid = false
	l.position = local
	host.add_child(l)
	return l


func lever(x: float, z: float, near_y: float, targets: Array, yaw := 0.0) -> Lever:
	var l := Lever.new()
	l.targets = targets
	l.position = ground_pos(x, z, near_y)
	l.rotation.y = yaw
	add_child(l)
	return l


## A ring of `count` stones orbiting `center`.
func carousel(center: Vector3, radius: float, count: int, period := 22.0) -> void:
	for i in count:
		var o := OrbitPlatform.new()
		o.center = center
		o.radius = radius
		o.period = period
		o.phase = float(i) / count * TAU
		add_child(o)


func slab(pos: Vector3, s := 1.0) -> Node3D:
	var n := Assets.spawn("slab", true, 2)
	n.position = pos
	n.rotation.y = rng.randf() * TAU
	n.scale = Vector3.ONE * s
	add_child(n)
	return n


func crumble(pos: Vector3, mat := "crumble") -> CrumblePlatform:
	var c := CrumblePlatform.new()
	c.mat = mat
	c.position = pos
	c.rotation.y = rng.randf() * TAU
	add_child(c)
	return c


func mover(a: Vector3, b: Vector3, travel := 7.0, asset := "slab") -> MovingPlatform:
	var m := MovingPlatform.new()
	m.a = a
	m.b = b
	m.travel = travel
	m.asset = asset
	add_child(m)
	return m


func gust(center: Vector3, size: Vector3, dir: Vector3, strength := 9.0, period := 7.0, on_time := 4.0) -> GustZone:
	var g := GustZone.new()
	g.size = size
	g.dir = dir.normalized()
	g.strength = strength
	g.period = period
	g.on_time = on_time
	g.position = center
	add_child(g)
	return g


# ------------------------------------------------------------ puzzles

func plate(x: float, z: float, near_y: float) -> PressurePlate:
	var p := PressurePlate.new()
	p.position = ground_pos(x, z, near_y) + Vector3(0, 0.05, 0)
	add_child(p)
	return p


func stone(x: float, z: float, near_y: float) -> PushStone:
	var s := PushStone.new()
	s.position = ground_pos(x, z, near_y) + Vector3(0, 0.3, 0)
	add_child(s)
	return s


## `base_yaw` aligns the mirror's 45° steps with a puzzle laid out at an angle.
func mirror(x: float, z: float, near_y: float, step := 0, base_yaw := 0.0) -> Mirror:
	var m := Mirror.new()
	m.step = step
	m.position = ground_pos(x, z, near_y)
	m.rotation.y = base_yaw
	add_child(m)
	return m


func emitter(x: float, z: float, near_y: float, toward: Vector3) -> BeamEmitter:
	var e := BeamEmitter.new()
	var p := ground_pos(x, z, near_y)
	var d := toward - p
	d.y = 0.0
	e.transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), p)
	add_child(e)
	return e


func receiver(x: float, z: float, near_y: float) -> BeamReceiver:
	var r := BeamReceiver.new()
	r.position = ground_pos(x, z, near_y)
	add_child(r)
	return r


func course(points: Array[Vector3], limit := 30.0) -> GateCourse:
	var c := GateCourse.new()
	c.points = points
	c.time_limit = limit
	add_child(c)
	return c


func sundial(x: float, z: float, near_y: float) -> Sundial:
	var s := Sundial.new()
	s.position = ground_pos(x, z, near_y)
	add_child(s)
	return s


# ------------------------------------------------------------ chapter finale escape

## Radius of the island under `p` (from the islands placed so far).
func island_radius_at(p: Vector3) -> float:
	var best := 12.0
	var best_d := INF
	for isl in _islands:
		var d := Vector2(isl.pos.x - p.x, isl.pos.z - p.z).length()
		if d < best_d:
			best_d = d
			best = isl.r
	return best


## Builds the escape: a launch pad at the start island's rim, a chain of boost rings toward the
## most open stretch of sky, and a far platform. Returns where the escape beam stands.
func build_escape() -> Vector3:
	var c := monolith.global_position
	var r0 := island_radius_at(c)
	var best_a := 0.0
	var best_score := -INF
	for k in 36:
		var a := k * TAU / 36.0
		var d := Vector3(cos(a), 0, sin(a))
		var score := 1000.0
		for isl in _islands:
			var rel: Vector3 = isl.pos - c
			rel.y = 0.0
			if rel.length() < r0 + 4.0:
				continue
			var t: float = clamp(rel.dot(d), 0.0, 230.0)
			score = minf(score, (rel - d * t).length() - isl.r)
		if score > best_score:
			best_score = score
			best_a = a
	var d := Vector3(cos(best_a), 0, sin(best_a))
	var padp := rim(c, d, 3.0)
	var cy := padp.y
	var pts: Array[Vector3] = []
	for i in 3:
		var p := c + d * (r0 + 17.0 + 38.0 * i)
		p.y = cy + 10.0 - 2.5 * i
		pts.append(p)
	var tp: Vector3 = pts[-1] + d * 50.0
	tp.y = pts[-1].y - 7.0
	island("island_mid", tp, rng.randf() * TAU, 10.0, {"flowers": true})
	await get_tree().physics_frame
	await get_tree().physics_frame
	_grass(_islands[-1])
	pad(padp.x, padp.z, cy)
	for p in pts:
		ring(p, p + d * 20.0)
	var g := ground_pos(tp.x, tp.z, tp.y)
	var lamp := cairn(g.x - d.z * 4.0, g.z + d.x * 4.0, g.y)
	lamp.scale = Vector3.ONE * 0.9
	return g


## Falling rocks around the start island's rim while it collapses. Free the node to stop it.
func collapse_fx(c: Vector3, r: float) -> Node3D:
	var holder := Node3D.new()
	add_child(holder)
	var tm := Timer.new()
	tm.wait_time = 0.22
	tm.autostart = true
	holder.add_child(tm)
	var rocks := ["rock_a", "rock_b", "rock_c", "rock_d"]
	tm.timeout.connect(func():
		var a := randf() * TAU
		var p := c + Vector3(cos(a), 0, sin(a)) * r * randf_range(0.75, 1.05)
		var g := ground_pos(p.x, p.z, c.y)
		var rock := Assets.spawn(rocks[randi() % rocks.size()], false)
		rock.position = g + Vector3.DOWN * randf_range(0.5, 3.0)
		rock.scale = Vector3.ONE * randf_range(0.6, 1.5)
		holder.add_child(rock)
		var t := rock.create_tween().set_parallel(true)
		t.tween_property(rock, "position:y", rock.position.y - 90.0, 3.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(rock, "rotation", Vector3(randf() * 4.0, randf() * 4.0, randf() * 4.0), 3.5)
		t.chain().tween_callback(rock.queue_free)
		if randf() < 0.12:
			Sound.play_at("crack", g, -4.0, randf_range(0.8, 1.1)))
	return holder


# ------------------------------------------------------------ enemies + checkpoints

func wisp(home: Vector3, radius := 6.0, night_only := false) -> Wisp:
	_wisps += 1
	if not decor_only and not Difficulty.keep_enemy(_wisps):
		return null
	var w := Wisp.new()
	w.home = home
	w.radius = radius
	w.night_only = night_only
	add_child(w)
	return w


func sentinel(x: float, z: float, near_y: float) -> Sentinel:
	_sentinels += 1
	if not decor_only and not Difficulty.keep_enemy(_sentinels + 1):
		return null
	var s := Sentinel.new()
	s.position = ground_pos(x, z, near_y) - Vector3(0, 0.1, 0)
	s.rotation.y = rng.randf() * TAU
	add_child(s)
	return s


func cairn(x: float, z: float, near_y: float) -> Cairn:
	var c := Cairn.new()
	c.position = ground_pos(x, z, near_y)
	add_child(c)
	return c


func hint(pos: Vector3, radius: float, key: String, text: String) -> void:
	var h := HintZone.new()
	h.key = key
	h.text = text
	h.radius = radius
	h.position = pos
	add_child(h)


# ------------------------------------------------------------ scenery

func waterfall(x: float, z: float, near_y: float, out: Vector3, length := 70.0) -> void:
	var w := Waterfall.new()
	w.top = ground_pos(x, z, near_y) + Vector3(0, 0.05, 0)
	w.out = out
	w.length = length
	add_child(w)


func birds(center: Vector3, count := 9, radius := 45.0) -> void:
	var b := Birds.new()
	b.center = center
	b.count = count
	b.radius = radius
	add_child(b)


func debris(c: Vector3, r: float) -> void:
	var rocks := ["rock_a", "rock_b", "rock_c", "rock_d"]
	for i in int(4 + r / 3.0):
		var n := Assets.spawn(rocks[rng.randi() % 4], false)
		var a := rng.randf() * TAU
		var d := r * rng.randf_range(1.1, 1.5)
		n.position = c + Vector3(cos(a) * d, rng.randf_range(-8.0, -1.0), sin(a) * d)
		n.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		n.scale = Vector3.ONE * rng.randf_range(0.25, 0.9) * (r / 12.0 + 0.4)
		add_child(n)
		_floaters.append([n, n.position.y, rng.randf() * TAU, rng.randf_range(-0.15, 0.15)])


func distant_islands(count := 18, opts := {}) -> void:
	var kinds := ["island_mid", "island_small_a", "island_small_c", "island_east", "island_west", "island_north", "island_tall", "island_long"]
	var overrides := {}
	if opts.has("grass"):
		overrides["grass"] = opts["grass"]
	if opts.has("rock"):
		overrides["rock"] = opts["rock"]
	for i in count:
		var a := float(i) / count * TAU + rng.randf_range(-0.15, 0.15)
		var d := rng.randf_range(200.0, 480.0)
		var n := Assets.spawn(kinds[rng.randi() % kinds.size()], false, 2, false, overrides)
		n.position = Vector3(cos(a) * d, rng.randf_range(-35.0, 55.0), sin(a) * d)
		n.rotation.y = rng.randf() * TAU
		n.scale = Vector3.ONE * rng.randf_range(1.5, 3.5)
		add_child(n)
		_floaters.append([n, n.position.y, rng.randf() * TAU, 0.0])


## Effects parented here follow the player each frame (rain, lanterns).
func follow_fx(n: Node3D) -> void:
	add_child(n)
	_followers.append(n)


func _make_clouds() -> void:
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1800, 1800)
	pm.subdivide_width = 180
	pm.subdivide_depth = 180
	sea.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/cloud_sea.gdshader")
	sea.material_override = m
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.position.y = kill_y - 18.0
	sea.extra_cull_margin = 40.0
	add_child(sea)
	_clouds.append(sea)
	cycle.cloud_mats.append(m)
	for y in [kill_y + 5.0, kill_y + 30.0]:
		var w := MeshInstance3D.new()
		var wp := PlaneMesh.new()
		wp.size = Vector2(1400, 1400)
		w.mesh = wp
		var wm := ShaderMaterial.new()
		wm.shader = preload("res://shaders/wisps.gdshader")
		wm.set_shader_parameter("opacity", 0.4 if y < kill_y + 10.0 else 0.18)
		wm.set_shader_parameter("scale", 0.012 if y < kill_y + 10.0 else 0.02)
		w.material_override = wm
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.position.y = y
		add_child(w)
		_clouds.append(w)
		cycle.cloud_mats.append(wm)


# ------------------------------------------------------------ grass + flowers

static func _blade_mesh(flower := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 7 if not flower else 9
	for b in (5 if not flower else 3):
		var a := r.randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.0, 0.12 if not flower else 0.2)
		var face := r.randf() * TAU
		var side := Vector3(cos(face), 0, sin(face))
		var bend := Vector3(-side.z, 0, side.x) * r.randf_range(0.05, 0.15)
		var h := r.randf_range(0.16, 0.32) if not flower else r.randf_range(0.25, 0.4)
		var w := 0.022 if not flower else 0.012
		var pts := [off - side * w, off + side * w,
			off - side * w * 0.6 + Vector3(0, h * 0.55, 0) + bend * 0.3, off + side * w * 0.6 + Vector3(0, h * 0.55, 0) + bend * 0.3,
			off + Vector3(0, h, 0) + bend]
		var vs := [0.0, 0.0, 0.55, 0.55, 0.79]
		var tris := [[0, 1, 2], [1, 3, 2], [2, 3, 4]]
		for tri in tris:
			for k in tri:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(0.5, vs[k]))
				st.add_vertex(pts[k])
		if flower:
			var top: Vector3 = pts[4]
			var hs := 0.05
			for q in [[Vector3(-hs, 0, 0), Vector3(hs, 0, 0)], [Vector3(0, 0, -hs), Vector3(0, 0, hs)]]:
				var a0: Vector3 = top + q[0]
				var a1: Vector3 = top + q[1]
				for v in [a0, a1, top + Vector3(0, hs * 1.6, 0), a0, top + Vector3(0, -hs * 0.4, 0), a1]:
					st.set_normal(Vector3.UP)
					st.set_uv(Vector2(0.5, 0.95))
					st.add_vertex(v)
	return st.commit()


func _grass(isl: Dictionary) -> void:
	var c: Vector3 = isl.pos
	var r: float = isl.r
	var dens := Settings.grass_density() * (0.5 if decor_only else 1.0)
	var blades: Array[Transform3D] = []
	var bcol: Array[Color] = []
	var flowers: Array[Transform3D] = []
	var fcol: Array[Color] = []
	var palette := [Color(1, 1, 0.95), Color(1.0, 0.85, 0.3), Color(1.0, 0.6, 0.75), Color(0.75, 0.65, 1.0)]
	var count := int(PI * r * r * 9.0 * dens)
	for i in count:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r * 1.15
		var x := c.x + cos(a) * d
		var z := c.z + sin(a) * d
		var hit := ground(x, z, c.y + 15.0, 1 | 2)
		if hit.is_empty() or hit.normal.y < 0.8 or not hit.collider.has_meta("terrain"):
			continue
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.75, 1.3))
		var xf := Transform3D(b, hit.position - Vector3(0, 0.03, 0))
		if isl.flowers and rng.randf() < 0.06:
			flowers.append(xf)
			fcol.append(palette[rng.randi() % palette.size()])
		else:
			blades.append(xf)
			var v := rng.randf_range(0.85, 1.1)
			bcol.append(Color(v, v, v))
	var kind: String = isl.grass
	var blade_mat: String = {"grass_gold": "grass_blades_gold", "grass_storm": "grass_blades_storm", "grass_snow": "grass_blades_snow",
		"grass_sand": "grass_blades_sand", "grass_crystal": "grass_blades_crystal", "grass_ash": "grass_blades_storm"}.get(kind, "grass_blades")
	_multimesh(_blade_mesh(), blades, bcol, blade_mat)
	if not flowers.is_empty():
		_multimesh(_blade_mesh(true), flowers, fcol, "flowers")
		var bf := FX.butterflies(Vector3(r * 0.6, 1.5, r * 0.6))
		bf.position = c + Vector3(0, 2.0, 0)
		add_child(bf)


## Scatters small Quaternius plants, flowers, mushrooms and pebbles over an island.
func _flora(isl: Dictionary) -> void:
	var c: Vector3 = isl.pos
	var r: float = isl.r
	var n := int(r * r * 0.18 * Settings.grass_density())
	for i in n:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * r * 1.05
		var hit := ground(c.x + cos(a) * d, c.z + sin(a) * d, c.y + 15.0, 1 | 2)
		if hit.is_empty() or not hit.collider.has_meta("terrain") or hit.normal.y < 0.8:
			continue
		var m: String = FLORA[rng.randi() % FLORA.size()]
		var f := Assets.spawn("nature/" + m, false)
		f.position = hit.position - Vector3(0, 0.05, 0)
		f.rotation.y = rng.randf() * TAU
		f.scale = Vector3.ONE * rng.randf_range(0.45, 0.8) * (0.6 if m.begins_with("Flower") or m.begins_with("Grass") else 1.0)
		add_child(f)


func _multimesh(mesh: Mesh, xforms: Array[Transform3D], colors: Array[Color], mat: String) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Mats.get_mat(mat)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _process(dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for f in _floaters:
		var n: Node3D = f[0]
		n.position.y = f[1] + sin(t * 0.4 + f[2]) * 0.6
		n.rotation.y += f[3] * dt
	if follow:
		var p := follow.global_position
		for cl in _clouds:
			cl.position.x = snappedf(p.x, 20.0)
			cl.position.z = snappedf(p.z, 20.0)
		for fx in _followers:
			fx.global_position = Vector3(p.x, p.y, p.z)
		for k in ["grass_blades", "grass_blades_gold", "grass_blades_storm", "grass_blades_snow", "grass_blades_sand", "grass_blades_crystal", "flowers"]:
			(Mats.get_mat(k) as ShaderMaterial).set_shader_parameter("player_pos", p)
