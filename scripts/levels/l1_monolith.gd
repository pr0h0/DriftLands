extends LevelBase
## Tutorial: walking, jumping, gliding and updrafts across a calm golden-hour archipelago.


func _init() -> void:
	par_time = 240.0
	title = "The Monolith"
	subtitle = "the light has left the monolith"
	mood = "dawn"
	sky = {"hour": 17.3, "day_length": 1200.0}
	spawn_point = Vector3(0, 1.5, 13.5)
	nature = true


func islands() -> void:
	island("island_hub", Vector3.ZERO, 0.0, 24.0, {"flowers": true})
	island("island_small_a", Vector3(33, -1.5, 5), 0.5, 5.0)
	island("island_small_b", Vector3(46, -3.0, -3), 1.3, 4.5)
	island("island_small_c", Vector3(59, -5.0, 4), 2.1, 5.5)
	island("island_east", Vector3(84, -8, 0), 0.0, 14.0)
	island("island_north", Vector3(0, 16, -80), 0.0, 12.0, {"flowers": true})
	island("island_mid", Vector3(-46, -9, 14), 0.7, 10.0, {"flowers": true})
	island("island_west", Vector3(-88, -18, 24), 0.0, 15.0, {"grass": "grass_gold"})
	secret_island("island_small_b", Vector3(25, -4, 45), 4.5)
	island("island_small_c", Vector3(-31.3, 0, 43.7), 0.3, 5.5, {"flowers": true})
	distant_islands()


func layout() -> void:
	_hub()
	_east()
	_north()
	_west()
	_minor()
	var edge := rim(Vector3.ZERO, Vector3(-0.25, 0, 1), 0.6)
	waterfall(edge.x, edge.z, edge.y, Vector3(-0.25, 0, 1))
	birds(Vector3(0, 30, 0), 9, 50.0)
	hint(Vector3(26, 1, 4), 5.0, "stones", "Jump across the stones. Hold %s to run for longer jumps." % Settings.key_label("sprint"))
	hint(Vector3(-21, 1, 4), 5.0, "glide", "Jump off the edge, then press %s again in mid-air to open your glider." % Settings.key_label("jump"))
	hint(Vector3(84, -7, 0), 9.0, "return_e", "Shards fly home on their own. Ride the updraft to get back up.")
	hint(Vector3(-88, -17, 24), 9.0, "return_w", "Shards fly home on their own. Ride the updraft to get back up.")

	_extras()


## Optional content: hidden fragments, a secret islet and a side puzzle.
func _extras() -> void:
	secret_route(Vector3.ZERO, Vector3(25, -4, 45))
	mushroom_fragment(-7, 12.1, 0.0)
	fragment(Vector3(7, 36, -22))
	var echo_pts := stones_between(Vector3.ZERO, Vector3(-31.3, 0, 43.7))
	echo_path(rim(Vector3.ZERO, (Vector3(-31.3, 0, 43.7) - Vector3.ZERO).normalized(), 3.0), echo_pts)
	var eg := ground_pos(Vector3(-31.3, 0, 43.7).x, Vector3(-31.3, 0, 43.7).z, Vector3(-31.3, 0, 43.7).y)
	fragment(eg + Vector3(0, 1.3, 0))
	secret_route(Vector3(-31.3, 0, 43.7), Vector3.ZERO)

func on_start() -> void:
	await get_tree().create_timer(6.5).timeout
	if session.hud:
		if Touch.active:
			session.first_hint("move", "Move with the stick on the left · Drag anywhere else to look · Tap Jump to jump")
		else:
			session.first_hint("move", "Move with %s/%s/%s/%s or arrow keys · Mouse to look · %s to jump" % [
				Settings.key_label("move_forward"), Settings.key_label("move_left"), Settings.key_label("move_back"),
				Settings.key_label("move_right"), Settings.key_label("jump")])
	await get_tree().create_timer(7.0).timeout
	session.first_hint("goal", "Find the three light shards and return them to the monolith. Arches point the way.")
	session.player.fell.connect(func(): session.first_hint("fall", "Fell? You're returned to solid ground. Press %s to do it yourself." % Settings.key_label("respawn")))


func _hub() -> void:
	var c := Vector3.ZERO
	plaza_monolith(c)
	var kinds := ["pillar_tall", "pillar_broken_a", "pillar_tall", "pillar_broken_b", "pillar_tall", "pillar_fallen",
		"pillar_tall", "pillar_broken_a", "pillar_tall", "pillar_broken_b", "pillar_tall", "pillar_broken_a"]
	for i in 12:
		var a := deg_to_rad(15.0 + i * 30.0)
		var p := polar(c, a, 11.6)
		put(kinds[i], p.x, p.y, 0.0, a + PI / 2 if kinds[i] == "pillar_fallen" else rng.randf() * TAU, 1.0, 0.1)
	for d in [[Vector2(1, 0), "arch"], [Vector2(0, -1), "arch"], [Vector2(-1, 0), "arch_broken"]]:
		var dv: Vector2 = d[0]
		put(d[1], dv.x * 15.5, dv.y * 15.5, 0.0, atan2(dv.x, dv.y) + PI / 2, 1.0, 0.1)
	for w in [[40.0, "wall_a"], [140.0, "wall_b"], [228.0, "wall_a"], [305.0, "wall_b"]]:
		var a := deg_to_rad(w[0])
		var p := polar(c, a, 18.5)
		put(w[1], p.x, p.y, 0.0, -a + PI / 2, 1.0, 0.15)
	var avoid := [Vector3(15.5, 0, 4.0), Vector3(0, -15.5, 4.0), Vector3(-15.5, 0, 4.0), Vector3(0, -20, 5.0), Vector3(0, 13.5, 3.0)]
	scatter(c, 16.5, 21.5, 9, ["tree_a", "tree_b", "tree_blossom", "pine_a", "tree_a", "tree_blossom"], 0.85, 1.2, true, avoid)
	scatter(c, 13.0, 22.0, 14, ["bush_a", "bush_b", "bush_flower"], 0.8, 1.3, false, avoid)
	scatter(c, 17.0, 23.0, 8, ["rock_a", "rock_b", "rock_c", "rock_d"], 0.6, 1.4, true, avoid)
	updraft(0, -20.5, 0.0, 40.0)


func _east() -> void:
	var c := Vector3(84, -8, 0)
	shrine_shard(c.x, c.z, c.y)
	for i in 4:
		var a := deg_to_rad(30.0 + i * 90.0 + rng.randf_range(-12, 12))
		var p := polar(c, a, 6.5)
		put("wall_a" if i % 2 == 0 else "wall_b", p.x, p.y, c.y, -a + PI / 2, 1.0, 0.15)
	for a_deg in [75.0, 255.0]:
		var p := polar(c, deg_to_rad(a_deg), 4.0)
		put("pillar_broken_b" if a_deg < 100 else "pillar_tall", p.x, p.y, c.y, rng.randf() * TAU)
	var avoid := [Vector3(76, 2, 5.5)]
	scatter(c, 8.0, 12.5, 7, ["pine_a", "pine_b"], 0.8, 1.2, true, avoid)
	scatter(c, 7.0, 13.0, 6, ["rock_a", "rock_c", "rock_d", "bush_a"], 0.6, 1.3, true, avoid)
	updraft(76, 2, c.y, 46.0)


func _north() -> void:
	var c := Vector3(0, 16, -80)
	var stairs := put("stairs", c.x, c.z + 3.5, c.y, 0.0, 1.0, 0.05)
	if stairs:
		shard_at(stairs.position + Vector3(0, 1.8 + 1.6, -(6 * 0.55 + 2.0)))
	put("arch", c.x, c.z - 6.5, c.y, 0.0, 1.1, 0.1)
	for a_deg in [200.0, 235.0, 305.0, 340.0]:
		var p := polar(c, deg_to_rad(a_deg), 6.0)
		put("pillar_tall" if int(a_deg) % 2 == 0 else "pillar_broken_a", p.x, p.y, c.y, rng.randf() * TAU)
	var avoid := [Vector3(0, -76.5, 4.5), Vector3(0, -86.5, 3.5)]
	scatter(c, 7.0, 10.5, 3, ["tree_blossom", "tree_a"], 0.8, 1.0, true, avoid)
	scatter(c, 6.0, 11.0, 6, ["bush_flower", "bush_b", "rock_d"], 0.8, 1.2, false, avoid)


func _west() -> void:
	var c := Vector3(-88, -18, 24)
	shrine_shard(c.x + 1.0, c.z, c.y, 0.4)
	put("arch_broken", c.x + 5.0, c.z, c.y, PI / 2 + 0.2, 1.0, 0.1)
	put("pillar_fallen", c.x - 4.5, c.z + 5.0, c.y, 0.8)
	var avoid := [Vector3(-78, 20, 5.5), Vector3(c.x + 1, c.z, 4.0), Vector3(c.x + 5, c.z, 3.5)]
	scatter(c, 6.0, 13.0, 9, ["tree_autumn", "tree_autumn_b", "tree_autumn"], 0.8, 1.2, true, avoid)
	scatter(c, 5.0, 13.5, 8, ["bush_flower", "rock_a", "rock_b", "bush_b"], 0.7, 1.2, false, avoid)
	updraft(-78, 20, c.y, 48.0)


func _minor() -> void:
	put("tree_blossom", -46, 14, -9.0, 0.5, 1.3)
	put("pillar_broken_a", -42, 18, -9.0, 1.0)
	scatter(Vector3(-46, -9, 14), 3.0, 8.5, 5, ["rock_a", "rock_b", "bush_a", "bush_flower"], 0.7, 1.2, false)
	put("rock_c", 33, 6, -1.5, 0.3, 0.9)
	put("bush_flower", 31, 3, -1.5, 0.0, 1.0, 0.1, false)
	put("pillar_broken_b", 46, -3, -3.0, 0.7)
	put("tree_a", 60, 5, -5.0, 2.0, 0.8)
