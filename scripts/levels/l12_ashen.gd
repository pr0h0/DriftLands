extends LevelKit
## Ashen Reach: built with the route kit (see level_kit.gd).


func _init() -> void:
	title = "Ashen Reach"
	subtitle = "embers drift where the light burned out"
	mood = "storm"
	sky = {"hour": 17.4, "day_length": 3000.0, "clouds": 0.5, "fog": 1.3, "tint": Color(1.12, 0.82, 0.7)}
	palette = {"grass": "grass_ash", "rock": "rock_ash"}
	props = ["dead_tree", "rock_a", "rock_c", "rock_b", "pillar_broken_a"]
	start_asset = "island_big"
	weather = "embers"
	pass


func plan() -> void:
	var a := stones(S, 0.0, "crumble", 6, 0.6, "island_flat")
	a = rings(a, 10.0, 2, "island_mid")
	finish(a, "plates", 1, 1)
	var b := causeway(S, 120.0, 2, "island_tall")
	b = vent(b, 120.0, 12.0, "island_small_c")
	finish(b, "free", 0, 1, true)
	var c := glide(S, 240.0, 5.0, "island_mid")
	c = stones(c, 245.0, "crumble", 4, 1.0, "island_small_a")
	finish(c, "bells", 2, 0)


func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l12_ashen", "Three shards, three routes. Find them all.")
