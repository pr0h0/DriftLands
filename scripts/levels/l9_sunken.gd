extends LevelBase
## Sunken Sky (desert noon). East: two turning causeways in a row (the second lever rides the
## first). North: aim the sun-lens beam through a prism to raise a bridge and break a seal.
## West: launch pads hop up to a guarded plateau.

const S := Vector3(0, 0, 0)
const A := Vector3(95, -3, 0)
const B1 := Vector3(-6, 0, -50)
const B2 := Vector3(-6, 0, -84)
const B3 := Vector3(-38, 0, -50)
const P1 := Vector3(-40, 6, 6)
const P2 := Vector3(-70, 14, -10)
const C := Vector3(-104, 22, -20)
const SAND := {"grass": "grass_sand", "rock": "rock_sand"}


func _init() -> void:
	par_time = 540.0
	title = "Sunken Sky"
	subtitle = "turn the old ways; bend the sun"
	mood = "desert"
	sky = {"hour": 13.5, "day_length": 3000.0, "clouds": 0.15, "fog": 1.2, "tint": Color(1.06, 0.95, 0.84)}
	spawn_point = Vector3(0, 1.5, 11)


func islands() -> void:
	biome = SAND
	island("island_big", S, 1.1, 18.0, SAND)
	island("island_tall", A, 0.3, 9.0, SAND)
	island("island_small_a", B1, 0.2, 5.0, SAND)
	island("island_small_c", B2, 1.4, 5.5, SAND)
	island("island_small_b", B3, 2.0, 4.5, SAND)
	island("island_small_b", P1, 0.6, 4.5, SAND)
	island("island_small_a", P2, 1.9, 5.0, SAND)
	island("island_flat", C, 0.3, 11.0, SAND)
	secret_island("island_small_a", Vector3(40, -5, 40), 5.0)
	distant_islands(16, SAND)


func layout() -> void:
	plaza_monolith(S, 0.2)
	scatter(S, 11.0, 16.5, 10, ["cactus", "dead_tree", "cactus", "rock_b", "rock_c"], 0.8, 1.3, true,
		[Vector3(15, 4, 4.0), Vector3(0, -14, 4.0), Vector3(-14, 3, 4.0), Vector3(0, 11, 3.0), Vector3(6, -12, 4.0), Vector3(-6, -12, 3.0)])
	var holder := Node3D.new()
	holder.add_child(FX.sand([300, 500, 800, 1100][Settings.quality()]))
	follow_fx(holder)
	var wf := rim(S, Vector3(0.3, 0, 0.95), 0.6)
	waterfall(wf.x, wf.z, wf.y, Vector3(0.3, 0, 0.95))

	# --- East: two causeways; the second lever rides on the first
	var p1 := causeway_pivot(S, Vector3.RIGHT)
	var t1 := turning(p1, 90.0, 90.0)
	var t2 := turning(p1 + Vector3(31.0, 0, 0), 90.0, 90.0)
	lever(15, 4, S.y, [t1])
	lever_on(t1, Vector3(2.4, 0, 2.0), [t2])
	shrine_shard(A.x, A.z, A.y)
	sentinel(A.x + 6, A.z - 5, A.y)
	put("wall_b", A.x - 3, A.z - 3, A.y, 0.8)
	updraft(A.x + 2.0, A.z + 6.0, A.y, 34.0)

	# --- North: sun-lens beam, mirror, prism, two crystals
	pad(0, -14, S.y, 18.0)
	emitter(6, -12, S.y, Vector3(-20, 0, -12))
	mirror(-6, -12, S.y, 1)
	prism(B1.x, B1.z, B1.y)
	var r1 := receiver(B2.x, B2.z + 3.0, B2.y)
	var r2 := receiver(B3.x, B3.z, B3.y)
	for p in stones_between(B1, B2):
		bridge(p, [r1])
	cage(shrine_shard(B2.x, B2.z - 2.0, B2.y), [r1, r2])
	updraft(B2.x + 3.0, B2.z - 1.0, B2.y, 30.0)
	hint(Vector3(0, 1, -12), 5.0, "lens", "The sun-lens fires across the void. Aim it at the far prism.")

	# --- West: launch-pad hops up to the plateau
	pad(-14, 3, S.y, 21.0)
	pad(P1.x, P1.z, P1.y, 24.0)
	pad(P2.x, P2.z, P2.y, 24.0)
	shrine_shard(C.x - 2.0, C.z - 3.0, C.y)
	sentinel(C.x + 7, C.z - 6, C.y)
	cairn(C.x + 5, C.z + 4, C.y)
	put("wall_a", C.x + 2, C.z - 1, C.y, 1.2)
	scatter(C, 6.0, 10.0, 5, ["cactus", "dead_tree", "rock_a"], 0.8, 1.2)
	_extras()


func _extras() -> void:
	secret_route(S, Vector3(40, -5, 40))
	mushroom_fragment(-9, -9, S.y)
	fragment(Vector3(A.x + 9, 30, A.z + 6))
	var b0 := bell(9, 9, S.y, 0.5)
	var b1 := bell(-11, 8, S.y, 2.2)
	var b2 := bell(-9, -6, S.y, 1.0)
	cage(fragment(ground_pos(9, -6, S.y) + Vector3.UP * 1.3), [b0, b1, b2])


func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l9", "East: turn the causeways. North: aim the sun. West: leap from pad to pad.")
