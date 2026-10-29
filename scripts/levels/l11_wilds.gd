extends LevelKit
## Hanging Wilds: built with the route kit (see level_kit.gd).


func _init() -> void:
	title = "Hanging Wilds"
	subtitle = "a forest that grew into the sky"
	mood = "bright"
	sky = {"hour": 9.5, "day_length": 3000.0, "clouds": 0.4}
	palette = {}
	props = ["tree_a", "tree_b", "pine_a", "bush_a", "bush_flower", "rock_a"]
	start_asset = "island_big"
	weather = ""
	nature = true


func plan() -> void:
	var a := vent(S, -60.0, 14.0, "island_mid")
	a = vent(a, -50.0, 12.0, "island_tall")
	finish(a, "free", 1, 0)
	var b := stones(S, 60.0, "slab", 5, 0.8, "island_small_c")
	b = glide(b, 70.0, 4.0, "island_flat")
	finish(b, "bells", 0, 0)
	var c := ferry(S, 180.0, "island_mid")
	c = vent(c, 190.0, 10.0, "island_small_a")
	finish(c, "free", 1, 0)


func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l11_wilds", "Three shards, three routes. Find them all.")
