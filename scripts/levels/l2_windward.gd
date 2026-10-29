extends LevelBase
## Windward Reach: bright midday. Chained updrafts (east), launch pad + boost rings and a
## pressure-plate seal (south), a ferry stone and a timed gate course (west).

const S := Vector3(0, 0, 0)
const A1 := Vector3(55, 12, -15)
const A2 := Vector3(115, 34, -5)
const B := Vector3(-6, -6, 165)
const C := Vector3(-75, -2, -2)


func _init() -> void:
	par_time = 360.0
	title = "Windward Reach"
	subtitle = "where the wind remembers every path"
	mood = "bright"
	sky = {"hour": 11.0, "day_length": 2400.0, "clouds": 0.3}
	spawn_point = Vector3(0, 1.5, 11)


func islands() -> void:
	island("island_big", S, 0.0, 18.0, {"flowers": true})
	island("island_tall", A1, 0.6, 9.0)
	island("island_flat", A2, 1.2, 11.0, {"flowers": true})
	island("island_long", B, 1.5708, 13.0, {"flowers": true})
	island("island_mid", C, 2.0, 12.0, {"scale": 1.2})
	secret_island("island_small_a", Vector3(40, -5, 35), 5.0)
	distant_islands(16)


func layout() -> void:
	plaza_monolith(S, 0.0)
	scatter(S, 11.0, 16.5, 8, ["pine_a", "tree_a", "tree_blossom", "pine_b"], 0.8, 1.15, true,
		[Vector3(14, -6, 5.5), Vector3(-6, 13, 4.0), Vector3(0, 11, 3.0), Vector3(-17, 2, 4.0)])
	scatter(S, 10.0, 17.0, 10, ["bush_a", "bush_flower", "rock_d"], 0.8, 1.2, false)
	var wf := rim(S, Vector3(0.6, 0, 0.8), 0.6)
	waterfall(wf.x, wf.z, wf.y, Vector3(0.6, 0, 0.8))
	birds(Vector3(20, 35, 40), 10, 60.0)

	# --- East: chained updrafts
	updraft(14, -6, S.y, 34.0)
	hint(Vector3(14, 1, -6), 7.0, "chain", "Updrafts chain together. Rise, glide to the next island, rise again.")
	updraft(A1.x, A1.z, A1.y, 44.0)
	scatter(A1, 4.0, 8.0, 3, ["pine_a", "rock_c"], 0.8, 1.0, true, [Vector3(A1.x, A1.z, 5.5)])
	shrine_shard(A2.x, A2.z, A2.y)
	for a in [0.4, 2.1, 3.9]:
		var p := polar(A2, a, 5.5)
		put("pillar_tall" if a < 2 else "pillar_broken_a", p.x, p.y, A2.y, rng.randf() * TAU)
	scatter(A2, 6.5, 10.0, 4, ["tree_blossom", "bush_flower"], 0.8, 1.1)

	# --- South: launch pad -> boost rings -> plate puzzle
	pad(-6, 13, S.y)
	ring(Vector3(-6, 10, 30), Vector3(-6, 10, 60))
	ring(Vector3(-6, 7, 68), Vector3(-6, 5, 100))
	ring(Vector3(-6, 3, 106), Vector3(-6, 1, 140))
	var sb := shrine_shard(B.x, B.z + 7.0, B.y)
	var p1 := plate(B.x - 5.0, B.z - 2.0, B.y)
	var p2 := plate(B.x + 5.0, B.z - 2.0, B.y)
	stone(B.x, B.z - 7.0, B.y)
	cage(sb, [p1, p2])
	updraft(B.x + 7.0, B.z + 5.0, B.y, 48.0)
	ring(Vector3(1, 26, 100), Vector3(1, 26, 60))
	put("wall_a", B.x - 7.0, B.z + 7.0, B.y, 1.2)
	scatter(B, 9.0, 13.0, 5, ["tree_a", "pine_a", "rock_a"], 0.8, 1.1, true, [Vector3(B.x + 7, B.z + 5, 5.5)])

	# --- West: ferry stone -> gate course seal
	var from := rim(S, Vector3.LEFT) + Vector3(-2.8, -0.35, 0)
	var to := rim(C, Vector3.RIGHT) + Vector3(2.8, 0.0, 0)
	to.y = from.y
	mover(from, to, 8.0)
	hint(from + Vector3(4, 1, 0), 5.0, "ferry", "This stone ferries travelers across. Wait for it to return.")
	updraft(C.x + 7.0, C.z - 4.0, C.y, 34.0)
	var sc := shrine_shard(C.x - 2.0, C.z + 3.0, C.y)
	var pts: Array[Vector3] = [Vector3(-68, 29, -20), Vector3(-60, 23, -42), Vector3(-80, 17, -56),
		Vector3(-100, 11, -40), Vector3(-104, 5, -16), Vector3(-86, 0.5, -6)]
	cage(sc, [course(pts, 34.0)])
	hint(Vector3(C.x + 7, C.y + 2, C.z - 4), 6.0, "course_info", "Rise in the updraft, then fly through the golden gate to start the course.")
	scatter(C, 7.0, 11.0, 5, ["pine_b", "rock_b", "bush_a"], 0.8, 1.1, true, [Vector3(C.x + 7, C.z - 4, 5.5)])

	_landmarks()
	_extras()


## Vertical-slice polish: every destination gets a silhouette you can spot from afar.
func _landmarks() -> void:
	put("pillar_tall", A1.x + 4.0, A1.z - 3.0, A1.y, 0.3, 1.7)  # A1: the wind tower
	put("pillar_broken_a", A1.x - 4.0, A1.z + 3.5, A1.y, 1.1, 1.3)
	put("tree_blossom", A2.x - 4.0, A2.z + 4.5, A2.y, 0.2, 2.3)  # A2: the great blossom
	put("arch", B.x, B.z - 11.0, B.y, 0.0, 1.3)  # B: gateway facing home
	for k in 4:  # C: ring of tall pillars around the course island
		var p := polar(C, k * TAU / 4 + 0.6, 9.0)
		put("pillar_tall", p.x, p.y, C.y, rng.randf() * TAU, 1.3)
	var wf2 := rim(S, Vector3(-0.8, 0, -0.6), 0.6)
	waterfall(wf2.x, wf2.z, wf2.y, Vector3(-0.8, 0, -0.6))
	for p in [Vector2(7, 13), Vector2(-4, 15)]:
		put("bush_flower", p.x, p.y, S.y, rng.randf() * TAU, 1.2, 0.1, false)


## Optional content: hidden fragments, a secret islet and a side puzzle.
func _extras() -> void:
	secret_route(S, Vector3(40, -5, 35))
	mushroom_fragment(-10, -4, S.y)
	fragment(Vector3(63, 52, -15))
	var b0 := bell(12, 8, S.y, 0.6)
	var b1 := bell(-12, -9, S.y, 2.0)
	var b2 := bell(2, -14, S.y, 0.0)
	cage(fragment(ground_pos(8, -10, S.y) + Vector3.UP * 1.3), [b0, b1, b2])

func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l2", "Three shards: east past the updrafts, south through the rings, west across the ferry.")
