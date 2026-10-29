extends LevelBase
## Shattered Spire: a vertical level. East: elevator + rising crumbling stairs. West: elevator,
## ferry, second elevator, then a stone-on-plate light bridge. North: a carousel around the shard.

const S := Vector3(0, 0, 0)
const P1 := Vector3(36, 24, 0)
const P2 := Vector3(36, 30, -57)
const Q := Vector3(-80, 40, 4)
const B2 := Vector3(-80, 40, -32)
const N := Vector3(0, 12.5, -62)


func _init() -> void:
	par_time = 420.0
	title = "Shattered Spire"
	subtitle = "the way home is down; the shards are up"
	mood = "bright"
	sky = {"hour": 8.2, "day_length": 2400.0, "clouds": 0.45}
	spawn_point = Vector3(0, 1.5, 11)


func islands() -> void:
	island("island_big", S, 0.7, 18.0, {"flowers": true})
	island("island_flat", P1, 0.2, 11.0)
	island("island_small_c", P2, 1.0, 5.5, {"flowers": true})
	island("island_flat", Q, 2.2, 11.0)
	island("island_small_a", B2, 0.3, 5.0, {"flowers": true})
	island("island_small_b", N, 0.0, 4.5)
	for sp in [[Vector3(-55, 26, -15), 1.2], [Vector3(60, 10, -30), 1.6], [Vector3(-20, 30, -90), 2.0], [Vector3(20, -5, 50), 2.2]]:
		var n := Assets.spawn("basalt_spire", true, 1, true)
		n.position = sp[0]
		n.scale = Vector3.ONE * sp[1]
		add_child(n)
	secret_island("island_small_b", Vector3(-30, -6, 40), 4.5)
	distant_islands(16)


func layout() -> void:
	plaza_monolith(S, 0.3)
	scatter(S, 11.0, 16.5, 7, ["tree_blossom", "tree_a", "pine_a"], 0.85, 1.15, true,
		[Vector3(18, 0, 5.0), Vector3(-18, 4, 5.0), Vector3(0, -15, 5.0), Vector3(0, 11, 3.0)])
	var wf := rim(S, Vector3(-0.5, 0, 0.85), 0.6)
	waterfall(wf.x, wf.z, wf.y, Vector3(-0.5, 0, 0.85))
	birds(Vector3(0, 45, -20), 10, 55.0)

	# --- East: elevator, then crumbling stairs climbing north
	var e := rim(S, Vector3.RIGHT) + Vector3(2.8, -0.35, 0)
	mover(e, Vector3(e.x, P1.y - 0.3, e.z), 6.0, "slab")
	hint(e + Vector3(-3, 1, 0), 4.0, "elevator", "Elevator stones carry you up. Step on and wait.")
	for i in 6:
		crumble(Vector3(P1.x, P1.y + 1.0 + i * 1.0, P1.z - 15.0 - i * 6.5))
	wisp(Vector3(P1.x + 6, P1.y + 5, P1.z - 30), 5.0)
	shrine_shard(P2.x, P2.z, P2.y)
	cairn(P1.x + 4, P1.z + 3, P1.y)

	# --- West: elevator -> ferry -> elevator -> stone + plate light bridge
	var w := rim(S, Vector3(-1, 0, 0.2)) + Vector3(-2.8, -0.35, 0)
	mover(w, Vector3(w.x, 18.0, w.z), 6.0)
	slab(Vector3(w.x - 7.0, 18.0, w.z), 1.3)
	mover(Vector3(w.x - 14.0, 18.0, w.z), Vector3(-61.6, 18.0, w.z), 7.0)
	mover(Vector3(-64.0, 18.0, w.z), Vector3(-64.0, Q.y - 0.3, w.z), 6.0)
	sentinel(-55, -15, 30.0)
	var pl := plate(Q.x + 5.0, Q.z + 2.0, Q.y)
	stone(Q.x - 5.0, Q.z + 4.0, Q.y)
	var nz := rim(Q, Vector3.FORWARD).z
	for i in 3:
		bridge(Vector3(Q.x, Q.y, nz - 4.0 - i * 6.3), [pl])
	hint(Vector3(Q.x, Q.y + 1, Q.z), 7.0, "bridge", "Golden light bridges appear while their plate is held down. A stone can hold it for you.")
	shrine_shard(B2.x, B2.z, B2.y)

	# --- North: carousel around the shard islet
	updraft(0, -13, S.y, 24.0)
	carousel(N + Vector3(0, -0.5, 0), 12.0, 5, 22.0)
	hint(Vector3(0, 22, -30), 8.0, "carousel", "Carousel stones circle the islet. Time your landing, then hop inward.")
	shrine_shard(N.x, N.z, N.y)

	_extras()


## Optional content: hidden fragments, a secret islet and a side puzzle.
func _extras() -> void:
	secret_route(S, Vector3(-30, -6, 40))
	mushroom_fragment(-9, -4, S.y)
	fragment(Vector3(-7, 21, -13))
	var b0 := bell(10, 10, S.y, 0.8)
	var b1 := bell(-11, 8, S.y, 2.4)
	var b2 := bell(-6, -11, S.y, 0.0)
	cage(fragment(ground_pos(10, -8, S.y) + Vector3.UP * 1.3), [b0, b1, b2])

func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l5", "Every shard is high above. Find the way up: elevators east and west, wind to the north.")
