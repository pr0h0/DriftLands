extends LevelBase
## The Last Gale (storm). East: four-ring gauntlet through opposing gusts under fire.
## North: diagonal elevator onto a carousel, plate seal with wisps. West: three updrafts up into the storm.

const S := Vector3(0, 0, 0)
const A1 := Vector3(194, -1, 0)
const B := Vector3(0, 20, -72)
const P1 := Vector3(-35, 23, 0)
const P2 := Vector3(-70, 41, -10)
const C := Vector3(-105, 62, -30)
const STORM := {"grass": "grass_storm", "rock": "rock_dark"}

var _bolt_t := 5.0
var _rain: Node3D


func _init() -> void:
	par_time = 540.0
	title = "The Last Gale"
	subtitle = "the last beacon, the fiercest wind"
	mood = "storm"
	sky = {"hour": 16.0, "paused": true, "storm": 1.0, "fog": 1.2, "allow_skip": false}
	spawn_point = Vector3(0, 1.5, 11)


func islands() -> void:
	biome = STORM
	island("island_big", S, 2.0, 18.0, STORM)
	island("island_tall", A1, 0.5, 9.0, STORM)
	island("island_small_a", B, 1.0, 5.0, STORM)
	island("island_flat", C, 0.6, 11.0, STORM)
	slab(P1, 1.6)
	slab(P2, 1.6)
	for sp in [[Vector3(106, 0, -24), 1.3], [Vector3(140, -20, 30), 2.4], [Vector3(-60, 10, 40), 2.0], [Vector3(-118, 56, -12), 1.1],
			[Vector3(40, -15, -60), 2.2]]:
		var n := Assets.spawn("basalt_spire", true, 1, true, {"grass": "grass_storm"})
		n.position = sp[0]
		n.scale = Vector3.ONE * sp[1]
		n.rotation.y = rng.randf() * TAU
		add_child(n)
	secret_island("island_small_b", Vector3(35, -6, 38), 4.5)
	distant_islands(14, STORM)


func layout() -> void:
	plaza_monolith(S)
	scatter(S, 11.0, 16.0, 6, ["pine_a", "pine_b", "rock_c"], 0.8, 1.2, true,
		[Vector3(15, 0, 5.0), Vector3(0, -15, 5.0), Vector3(-15, 0, 5.0), Vector3(0, 11, 3.0)])
	_rain = Node3D.new()
	_rain.add_child(FX.rain([500, 900, 1400, 2000][Settings.quality()]))
	follow_fx(_rain)

	# --- East gauntlet
	pad(14, 0, S.y)
	ring(Vector3(30, 10, 0), Vector3(60, 10, 0))
	ring(Vector3(68, 8, 0), Vector3(100, 8, 0))
	ring(Vector3(106, 6, 0), Vector3(140, 6, 0))
	ring(Vector3(144, 4, 0), Vector3(180, 4, 0))
	gust(Vector3(48, 9, 0), Vector3(14, 22, 36), Vector3(0, 0, 1), 6.0, 6.0, 3.0)
	gust(Vector3(124, 6, 0), Vector3(14, 22, 36), Vector3(0, 0, -1), 6.0, 6.0, 3.0)
	sentinel(106, -24, 6.0)
	shrine_shard(A1.x, A1.z, A1.y)
	updraft(A1.x - 3.0, A1.z + 3.0, A1.y, 50.0)
	ring(Vector3(100, 26, 3), Vector3(60, 26, 3))

	# --- North: diagonal elevator -> carousel -> plate seal
	var n0 := rim(S, Vector3.FORWARD) + Vector3(0, -0.35, -2.8)
	mover(n0, Vector3(0, B.y - 0.3, -50), 8.0)
	carousel(B + Vector3(0, -0.4, 0), 12.0, 4, 20.0)
	var pl := plate(B.x - 1.5, B.z + 1.5, B.y)
	stone(B.x + 2.0, B.z - 1.0, B.y)
	cage(shrine_shard(B.x, B.z - 2.5, B.y), [pl])
	wisp(Vector3(B.x, B.y + 3, B.z), 7.0)
	wisp(Vector3(B.x, B.y + 4, B.z - 10), 6.0)

	# --- West: updraft chain up into the storm
	var u1 := rim(S, Vector3.LEFT, 4.0)
	updraft(u1.x, u1.z, S.y, 30.0)
	cairn(P1.x + 1.0, P1.z + 1.0, P1.y)
	updraft_at(P1 + Vector3(-1.5, 0, -1.5), 30.0)
	gust(Vector3(-52, 40, -5), Vector3(24, 30, 30), Vector3(0, 0, 1), 6.0, 7.0, 3.5)
	cairn(P2.x + 1.0, P2.z + 1.0, P2.y)
	updraft_at(P2 + Vector3(-1.5, 0, -1.5), 34.0)
	gust(Vector3(-88, 66, -20), Vector3(26, 30, 30), Vector3(1, 0, 0), 6.0, 8.0, 3.5)
	shrine_shard(C.x, C.z, C.y)
	sentinel(C.x - 7, C.z - 6, C.y)
	put("wall_b", C.x - 2.5, C.z - 2.5, C.y, 0.8)
	wisp(Vector3(C.x + 3, C.y + 3, C.z + 3), 6.0)

	_extras()


## Optional content: hidden fragments, a secret islet and a side puzzle.
func _extras() -> void:
	secret_route(S, Vector3(35, -6, 38))
	mushroom_fragment(-9, -6, S.y)
	fragment(Vector3(198, 44, 3))
	var b0 := bell(8, 11, S.y, 0.5)
	var b1 := bell(-10, 9, S.y, 2.2)
	var b2 := bell(-6, -11, S.y, 0.0)
	cage(fragment(ground_pos(9, -9, S.y) + Vector3.UP * 1.3), [b0, b1, b2])

func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l7", "The last beacon. East through four rings, north over the carousel, west up into the gale.")


func on_finale() -> void:
	create_tween().tween_property(cycle, "storm", 0.0, 10.0)
	create_tween().tween_property(cycle, "fog_mul", 0.8, 10.0)
	(_rain.get_child(0) as GPUParticles3D).emitting = false
	_bolt_t = INF


func _process(dt: float) -> void:
	super._process(dt)
	_bolt_t -= dt
	if _bolt_t <= 0.0:
		_bolt_t = rng.randf_range(6.0, 13.0)
		cycle.lightning()
		await get_tree().create_timer(rng.randf_range(0.5, 2.0)).timeout
		Sound.play("thunder", -4.0, rng.randf_range(0.85, 1.1))
