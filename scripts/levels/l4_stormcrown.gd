extends LevelBase
## Stormcrown: rain, lightning and gusts. Sentinels fire on sight, wisps never sleep.
## East: pad + rings through a gust; North: ferry + three-plate seal; West: high updraft chain.

const S := Vector3(0, 0, 0)
const A := Vector3(116, 1, 3)
const B := Vector3(2, -2, -82)
const C := Vector3(-98, 44, -6)
const P1 := Vector3(-46, 24, 5)

const STORM := {"grass": "grass_storm", "rock": "rock_dark"}

var _bolt_t := 6.0
var _rain: Node3D


func _init() -> void:
	par_time = 420.0
	title = "Stormcrown"
	subtitle = "carry the light through the storm"
	mood = "storm"
	sky = {"hour": 15.0, "paused": true, "storm": 1.0, "fog": 1.3, "allow_skip": false}
	spawn_point = Vector3(0, 1.5, 13)


func islands() -> void:
	biome = STORM
	island("island_big", S, -1.0, 20.7, {"scale": 1.15, "grass": "grass_storm", "rock": "rock_dark"})
	island("island_small_c", A, 0.4, 7.7, {"scale": 1.4, "grass": "grass_storm", "rock": "rock_dark"})
	island("island_long", B, 0.2, 13.0, STORM)
	island("island_tall", C, 0.9, 9.0, STORM)
	for sp in [[Vector3(128, 6, -14), 1.2], [Vector3(20, 4, -100), 1.3], [Vector3(-110, 40, 10), 1.1], [Vector3(-86, 42, -22), 1.0],
			[Vector3(60, -10, -40), 2.0], [Vector3(-40, -6, 60), 2.4], [Vector3(80, 20, 60), 1.8]]:
		var n := Assets.spawn("basalt_spire", true, 1, true, {"grass": "grass_storm"})
		n.position = sp[0]
		n.scale = Vector3.ONE * sp[1]
		n.rotation.y = rng.randf() * TAU
		add_child(n)
	var p1 := slab(P1, 1.6)
	p1.rotation.y = 0.3
	secret_island("island_small_a", Vector3(40, -5, 40), 5.0)
	island("island_small_c", Vector3(-30.5, 0, 40.6), 0.8, 5.5, STORM)
	distant_islands(14, STORM)


func layout() -> void:
	plaza_monolith(S)
	scatter(S, 12.0, 19.0, 7, ["pine_a", "pine_b", "rock_c", "rock_a"], 0.8, 1.2, true,
		[Vector3(16, 0, 5.0), Vector3(0, -20, 6.0), Vector3(-16, 3, 6.0), Vector3(0, 13, 3.0)])
	for i in 6:
		var a := i * TAU / 6
		var p := polar(S, a, 12.0)
		put(["pillar_broken_a", "pillar_broken_b", "pillar_fallen"][i % 3], p.x, p.y, S.y, rng.randf() * TAU)
	_rain = Node3D.new()
	_rain.add_child(FX.rain([500, 900, 1400, 2000][Settings.quality()]))
	follow_fx(_rain)

	# --- East: pad -> rings through a gust -> guarded islet
	pad(16, 0, S.y)
	ring(Vector3(34, 10, 0), Vector3(60, 10, 0))
	ring(Vector3(72, 5, 2), Vector3(100, 3, 2))
	gust(Vector3(53, 10, 1), Vector3(26, 24, 34), Vector3(0, 0, 1), 8.0)
	shrine_shard(A.x, A.z, A.y)
	sentinel(128, -14, 8.0)
	put("wall_b", A.x - 3.0, A.z + 3.5, A.y, 0.4)
	updraft(A.x - 4.0, A.z + 4.0, A.y, 40.0)
	hint(Vector3(A.x, A.y + 1, A.z), 8.0, "cover", "The sentinel sees you. Use the wall for cover.")

	# --- North: ferry -> three-plate seal with wisps
	var from := rim(S, Vector3.FORWARD) + Vector3(0, -0.35, -2.8)
	var to := rim(B, Vector3.BACK) + Vector3(0, 0, 2.8)
	to.y = from.y
	mover(from, to, 7.0)
	cairn(B.x - 6.0, B.z + 8.0, B.y)
	var sb := shrine_shard(B.x, B.z - 6.0, B.y)
	var plates := [plate(B.x - 6.0, B.z + 1.0, B.y), plate(B.x + 6.0, B.z + 1.0, B.y), plate(B.x, B.z - 0.5, B.y)]
	stone(B.x - 3.0, B.z + 5.0, B.y)
	stone(B.x + 3.0, B.z + 5.0, B.y)
	cage(sb, plates)
	put("wall_a", B.x - 8.0, B.z - 6.0, B.y, 0.9)
	put("wall_b", B.x + 8.0, B.z - 3.0, B.y, -0.6)
	wisp(Vector3(B.x, B.y + 2.5, B.z), 7.0)
	wisp(Vector3(B.x + 4, B.y + 3.0, B.z - 6), 5.0)
	sentinel(20, -100, 6.0)
	updraft(B.x + 8.0, B.z + 6.0, B.y, 34.0)

	# --- West: high updraft chain with a crosswind
	var u1 := rim(S, Vector3.LEFT, 4.0)
	updraft(u1.x, u1.z, S.y, 34.0)
	cairn(P1.x + 1.0, P1.z + 1.0, P1.y)
	updraft_at(P1 + Vector3(-1.5, 0, -1.5), 38.0)
	gust(Vector3(-72, 50, 0), Vector3(30, 30, 30), Vector3(0, 0, -1), 6.0, 8.0, 4.0)
	shrine_shard(C.x, C.z, C.y)
	sentinel(-110, 10, 40.0)
	wisp(Vector3(C.x, C.y + 3, C.z), 7.0)
	put("pillar_tall", C.x + 3.5, C.z - 2.0, C.y, 0.0)
	put("pillar_broken_a", C.x - 3.0, C.z + 3.0, C.y, 1.0)

	_extras()


## Optional content: hidden fragments, a secret islet and a side puzzle.
func _extras() -> void:
	secret_route(S, Vector3(40, -5, 40))
	mushroom_fragment(-10, -8, S.y)
	fragment(Vector3(119, 37, 7))
	var echo_pts := stones_between(S, Vector3(-30.5, 0, 40.6))
	echo_path(rim(S, (Vector3(-30.5, 0, 40.6) - S).normalized(), 3.0), echo_pts)
	var eg := ground_pos(Vector3(-30.5, 0, 40.6).x, Vector3(-30.5, 0, 40.6).z, Vector3(-30.5, 0, 40.6).y)
	fragment(eg + Vector3(0, 1.3, 0))
	secret_route(Vector3(-30.5, 0, 40.6), S)

func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l4", "East through the rings, north across the ferry, west up the wind. The storm fights you everywhere.")


func on_finale() -> void:
	create_tween().tween_property(cycle, "storm", 0.0, 10.0)
	create_tween().tween_property(cycle, "fog_mul", 0.8, 10.0)
	var r := _rain.get_child(0) as GPUParticles3D
	r.emitting = false
	set_process(true)
	_bolt_t = INF


func _process(dt: float) -> void:
	super._process(dt)
	_bolt_t -= dt
	if _bolt_t <= 0.0:
		_bolt_t = rng.randf_range(7.0, 16.0)
		cycle.lightning()
		await get_tree().create_timer(rng.randf_range(0.6, 2.2)).timeout
		Sound.play("thunder", -4.0, rng.randf_range(0.85, 1.1))
