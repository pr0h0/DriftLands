extends LevelBase
## Lantern Night: moonstone paths exist only at night (with wisps awake), sunstone paths only
## by day. A sundial swaps them. East holds a mirror puzzle.

const S := Vector3(0, 0, 0)
const A := Vector3(-80, 4, 0)
const B := Vector3(55, -8, 22)
const C := Vector3(0, 14, -112)


func _init() -> void:
	par_time = 420.0
	title = "Lantern Night"
	subtitle = "some paths only open in the dark"
	mood = "night"
	sky = {"hour": 22.5, "day_length": 3000.0, "allow_skip": false}
	spawn_point = Vector3(0, 1.5, 13)


func islands() -> void:
	island("island_hub", S, 1.2, 24.0, {"flowers": true})
	island("island_flat", A, 0.3, 11.0)
	island("island_big", B, 0.0, 18.0, {"grass": "grass_gold"})
	island("island_tall", C, 2.0, 9.0, {"flowers": true})
	secret_island("island_small_b", Vector3(35, -6, 40), 4.5)
	distant_islands(16)


func layout() -> void:
	plaza_monolith(S)
	sundial(7, 13, S.y)
	hint(Vector3(7, 1, 13), 4.0, "sundial", "The sundial turns day into night and back. Some paths only exist in one of them.")
	scatter(S, 15.0, 22.0, 10, ["tree_blossom", "tree_a", "pine_a", "tree_b"], 0.85, 1.2, true,
		[Vector3(-24, 0, 6.0), Vector3(0, -20, 6.0), Vector3(24, 6, 6.0), Vector3(7, 13, 4.0)])
	scatter(S, 12.0, 22.0, 12, ["bush_flower", "bush_a", "rock_a", "rock_d"], 0.8, 1.2, false)
	for i in 8:
		var a := i * TAU / 8 + 0.2
		var p := polar(S, a, 12.0)
		put(["pillar_tall", "pillar_broken_a", "pillar_broken_b"][i % 3], p.x, p.y, S.y, rng.randf() * TAU)
	var lan := FX.lanterns(Vector3(40, 8, 40), Color(1.0, 0.75, 0.4, 0.9), 70)
	lan.position = Vector3(0, 6, 0)
	add_child(lan)

	# --- West: moonstone path (night only) guarded by wisps
	var start := rim(S, Vector3.LEFT)
	for i in 6:
		phase(Vector3(start.x - 4.5 - i * 7.0, 0.5 + i * 1.0, sin(i * 1.3) * 1.5), "night")
	hint(Vector3(start.x - 1, 1, 0), 5.0, "moon", "Moonstones only exist at night. Jump from stone to stone.")
	wisp(Vector3(-40, 5, 6), 5.0, true)
	wisp(Vector3(-55, 7, -6), 5.0, true)
	cairn(A.x + 4.0, A.z + 4.0, A.y)
	shrine_shard(A.x, A.z, A.y)
	updraft(A.x - 4.0, A.z - 5.0, A.y, 30.0)
	scatter(A, 6.0, 10.0, 4, ["pine_a", "rock_c", "bush_b"], 0.8, 1.1, true, [Vector3(A.x - 4, A.z - 5, 5.5)])

	# --- East: mirror puzzle
	var e := emitter(B.x - 5.0, B.z - 4.5, B.y, Vector3(B.x + 10.0, B.y, B.z - 4.5))
	mirror(B.x + 4.5, B.z - 4.5, B.y, 1)
	mirror(B.x + 4.5, B.z + 4.5, B.y, 3)
	var r := receiver(B.x - 5.0, B.z + 4.5, B.y)
	var sb := shrine_shard(B.x, B.z, B.y)
	cage(sb, [r])
	hint(e.global_position + Vector3(0, 1, 0), 7.0, "mirror", "Guide the light into the far crystal. Turn the mirrors with %s." % Settings.key_label("interact"))
	cairn(B.x - 9.0, B.z - 10.0, B.y)
	wisp(Vector3(B.x, B.y + 5.0, B.z), 13.0, true)
	updraft(B.x + 10.0, B.z - 8.0, B.y, 36.0)
	scatter(B, 10.0, 17.0, 8, ["tree_autumn", "tree_autumn_b", "rock_a", "bush_flower"], 0.8, 1.15, true,
		[Vector3(B.x + 10, B.z - 8, 5.5), Vector3(B.x - 9, B.z - 10, 3.0)])

	# --- North: sunstones (day only) then crumbling stones
	updraft(0, -20, S.y, 33.0)
	for i in 3:
		phase(Vector3(0, 22.5 - i * 1.5, -38.0 - i * 10.0), "day")
	for i in 4:
		crumble(Vector3(0, 18.6 - i * 0.6, -65.0 - i * 7.0))
	hint(Vector3(0, 20, -58), 5.0, "crumble_tip", "Cracked stones fall soon after you land. Keep moving, and glide (%s in mid-air) over the gaps if you need to." % Settings.key_label("jump"))
	hint(Vector3(0, 24, -40), 6.0, "sun", "Sunstones vanish at night. Turn the sundial to bring them back.")
	shrine_shard(C.x, C.z, C.y)
	wisp(Vector3(C.x + 6, C.y + 3, C.z), 6.0, true)
	wisp(Vector3(C.x - 6, C.y + 3, C.z - 3), 6.0, true)
	updraft(C.x + 4.0, C.z - 4.0, C.y, 26.0)
	scatter(C, 4.0, 8.0, 3, ["tree_blossom", "bush_flower"], 0.8, 1.0, true, [Vector3(C.x + 4, C.z - 4, 5.0)])

	_extras()


## Optional content: hidden fragments, a secret islet and a side puzzle.
func _extras() -> void:
	secret_route(S, Vector3(35, -6, 40))
	mushroom_fragment(-8, -14, S.y)
	fragment(Vector3(-7, 30, -22))
	var em := emitter(7, 2, 0.0, Vector3(7, 0, 20))
	mirror(7, 7, 0.0, 3)
	prism(0, 7, 0.0)
	var ra := receiver(-8, 7, 0.0)
	var rb := receiver(0, 10.4, 0.0)
	cage(fragment(ground_pos(-5, -6, 0.0) + Vector3.UP * 1.3), [ra, rb])
	hint(em.global_position + Vector3.UP, 4.0, "prism", "Prisms split light in two. Light both crystals at once.")

func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l3", "Wisps only wake at night. Use the sundial wisely.")
