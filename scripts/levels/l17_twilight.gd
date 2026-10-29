extends LevelKit
## Twilight Archipelago: built with the route kit (see level_kit.gd).


func _init() -> void:
	title = "Twilight Archipelago"
	subtitle = "between day and night, both paths are half-real"
	mood = "night"
	sky = {"hour": 19.4, "day_length": 3000.0, "allow_skip": false, "clouds": 0.3}
	palette = {"grass": "grass_gold"}
	props = ["tree_autumn", "tree_autumn_b", "bush_flower", "rock_a"]
	start_asset = "island_hub"
	weather = ""
	pass


func plan() -> void:
	var a := stones(S, -30.0, "night", 5, 0.8, "island_mid")
	a = stones(a, -25.0, "day", 5, 0.8, "island_small_c")
	finish(a, "free", 2, 0)
	var b := stones(S, 90.0, "day", 6, 0.6, "island_flat")
	b = glide(b, 95.0, 4.0, "island_flat")
	finish(b, "mirror", 1, 1)
	var c := vent(S, 210.0, 14.0, "island_tall")
	c = stones(c, 215.0, "night", 5, 0.8, "island_small_a")
	finish(c, "bells", 2, 0)


func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l17_twilight", "Three shards, three routes. Find them all.")
