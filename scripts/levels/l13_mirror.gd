extends LevelKit
## Mirror Lake: built with the route kit (see level_kit.gd).


func _init() -> void:
	title = "Mirror Lake"
	subtitle = "still water, bent light"
	mood = "dawn"
	sky = {"hour": 7.2, "day_length": 3000.0, "clouds": 0.3}
	palette = {"grass": "grass_gold"}
	props = ["tree_a", "tree_blossom", "bush_flower", "rock_b"]
	start_asset = "island_big"
	weather = ""
	nature = true


func plan() -> void:
	var a := ferry(S, -90.0, "island_flat")
	finish(a, "mirror", 1, 0)
	var b := rings(S, 30.0, 3, "island_big")
	finish(b, "mirror", 0, 1)
	var c := stones(S, 150.0, "echo", 6, 0.3, "island_mid")
	c = elevator(c, 160.0, 12.0, "island_small_c")
	finish(c, "bells", 1, 0)


func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l13_mirror", "Three shards, three routes. Find them all.")
