extends LevelKit
## The First Beacon: built with the route kit (see level_kit.gd).


func _init() -> void:
	title = "The First Beacon"
	subtitle = "where every light began"
	mood = "triumph"
	sky = {"hour": 17.6, "day_length": 2400.0, "clouds": 0.35}
	palette = {}
	props = ["tree_blossom", "tree_a", "pillar_tall", "bush_flower", "rock_a"]
	start_asset = "island_hub"
	weather = ""
	nature = true


func plan() -> void:
	var a := rings(S, -90.0, 3, "island_mid")
	a = vent(a, -90.0, 16.0, "island_small_c")
	a = stones(a, -85.0, "crumble", 5, 1.0, "island_flat")
	a = causeway(a, -80.0, 2, "island_flat")
	finish(a, "mirror", 2, 1)
	var b := ferry(S, 30.0, "island_mid")
	b = elevator(b, 35.0, 14.0, "island_small_c")
	b = carousel_hop(b, 40.0)
	b = vent(b, 45.0, 14.0, "island_tall")
	finish(b, "bells", 2, 2)
	var c := stones(S, 150.0, "echo", 6, 0.4, "island_mid")
	c = rings(c, 155.0, 3, "island_flat")
	c = vent(c, 160.0, 16.0, "island_flat")
	finish(c, "plates", 2, 2)


func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l21_first", "Three shards, three routes. Find them all.")
