extends LevelBase
## Eclipse Gardens (night). East: aim a beam across the void to raise a light bridge.
## West: moonstones by night to a second sundial, then sunstones by day.
## North: crumbling climb to a mirror-sealed shard, guarded.

const S := Vector3(0, 0, 0)
const E1 := Vector3(60, 0, -4)
const E2 := Vector3(60, 0, -42)
const W1 := Vector3(-56, 4, 0)
const W2 := Vector3(-107, 9, 0)
const N := Vector3(0, 20, -96)


func _init() -> void:
	par_time = 480.0
	title = "Eclipse Gardens"
	subtitle = "bend the light, turn the sky"
	mood = "night"
	sky = {"hour": 22.5, "day_length": 3000.0, "allow_skip": false}
	spawn_point = Vector3(0, 1.5, 13)


func islands() -> void:
	island("island_hub", S, 2.6, 24.0, {"flowers": true})
	island("island_mid", E1, 0.4, 9.0, {"scale": 0.9})
	island("island_small_c", E2, 1.7, 5.5)
	island("island_east", W1, 1.0, 9.0, {"scale": 0.65})
	island("island_small_c", W2, 0.2, 5.5, {"grass": "grass_gold"})
	island("island_flat", N, 1.4, 11.0, {"grass": "grass_gold"})
	secret_island("island_small_a", Vector3(-20, -6, 50), 5.0)
	distant_islands(16)


func layout() -> void:
	plaza_monolith(S)
	sundial(-7, 13, S.y)
	scatter(S, 15.0, 22.0, 10, ["tree_blossom", "tree_autumn", "pine_a", "tree_b"], 0.85, 1.2, true,
		[Vector3(-24, 0, 6.0), Vector3(0, -20, 6.0), Vector3(18, -4, 5.0), Vector3(-7, 13, 4.0), Vector3(20, 4, 4.0)])
	var lan := FX.lanterns(Vector3(60, 10, 60), Color(1.0, 0.75, 0.4, 0.9), 90)
	add_child(lan)

	# --- East: pad over the gap, beam -> mirror -> receiver raises a bridge to E2
	pad(20, 4, S.y, 18.0)
	emitter(17, -4, S.y, Vector3(40, 0, -4))
	mirror(E1.x, E1.z, E1.y, 3)
	var rcv := receiver(E2.x, E2.z + 3.0, E2.y)
	var sz := rim(E1, Vector3.FORWARD).z
	for i in 4:
		bridge(Vector3(E1.x - 3.0, E1.y, sz - 3.5 - i * 6.0), [rcv])
	hint(Vector3(20, 1, 4), 4.0, "e_tip", "Light crosses the void. Find where it lands and send it onward.")
	shrine_shard(E2.x + 1.0, E2.z - 2.5, E2.y)
	updraft(E2.x - 3.0, E2.z - 1.0, E2.y, 30.0)

	# --- West: moonstones (night) -> W1 sundial -> sunstones (day)
	var wr := rim(S, Vector3.LEFT).x
	for i in 3:
		phase(Vector3(wr - 5.5 - i * 6.0, 1.0 + i * 1.2, 0), "night")
	wisp(Vector3(-36, 4, 5), 4.5, true)
	sundial(W1.x, W1.z, W1.y)
	cairn(W1.x + 3, W1.z + 4, W1.y)
	var w1r := rim(W1, Vector3.LEFT).x
	for i in 5:
		phase(Vector3(w1r - 5.0 - i * 6.5, W1.y + 0.8 + i * 0.8, sin(i * 1.1) * 1.2), "day")
	hint(Vector3(W1.x, W1.y + 1, W1.z), 6.0, "w_tip", "Another sundial. The path ahead only exists by day.")
	shrine_shard(W2.x, W2.z, W2.y)
	updraft(W2.x + 2.0, W2.z - 3.0, W2.y, 30.0)

	# --- North: crumbling climb -> guarded mirror seal
	updraft(0, -20, S.y, 32.0)
	for i in 6:
		crumble(Vector3(0, 25.4 - i * 0.6, -40.0 - i * 7.0))
	cairn(N.x - 6, N.z + 6, N.y)
	emitter(N.x - 5, N.z + 4, N.y, Vector3(N.x + 10, N.y, N.z + 4))
	mirror(N.x + 4.5, N.z + 4, N.y, 0)
	mirror(N.x + 4.5, N.z - 5, N.y, 2)
	var r2 := receiver(N.x - 5, N.z - 5, N.y)
	cage(shrine_shard(N.x, N.z, N.y), [r2])
	sentinel(N.x + 18, N.z - 4, N.y + 4.0)
	wisp(Vector3(N.x, N.y + 3, N.z), 8.0, true)
	put("wall_a", N.x + 9, N.z, N.y, PI / 2)

	_extras()


## Optional content: hidden fragments, a secret islet and a side puzzle.
func _extras() -> void:
	secret_route(S, Vector3(-20, -6, 50))
	mushroom_fragment(9, -12, S.y)
	fragment(Vector3(57, 26, -50))
	var em := emitter(7, 2, 0.0, Vector3(7, 0, 20))
	mirror(7, 7, 0.0, 3)
	prism(0, 7, 0.0)
	var ra := receiver(-8, 7, 0.0)
	var rb := receiver(0, 10.4, 0.0)
	cage(fragment(ground_pos(-5, -6, 0.0) + Vector3.UP * 1.3), [ra, rb])
	hint(em.global_position + Vector3.UP, 4.0, "prism", "Prisms split light in two. Light both crystals at once.")

func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l6", "East: follow the light. West: mind the hour. North: climb fast and take cover.")
