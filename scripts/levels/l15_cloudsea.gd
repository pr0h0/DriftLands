extends LevelKit
## Cloudsea Ruins: built with the route kit (see level_kit.gd).


func _init() -> void:
	title = "Cloudsea Ruins"
	subtitle = "where the first beacons were built"
	mood = "dawn"
	sky = {"hour": 6.6, "day_length": 3000.0, "clouds": 0.5}
	palette = {}
	props = ["pillar_broken_a", "pillar_tall", "tree_a", "bush_a", "rock_a"]
	start_asset = "island_hub"
	weather = ""
	nature = true


func plan() -> void:
	var a := glide(S, -40.0, 5.0, "island_mid")
	a = glide(a, -40.0, 5.0, "island_small_c")
	a = vent(a, -30.0, 16.0, "island_flat")
	finish(a, "mirror", 1, 0)
	var b := ferry(S, 80.0, "island_mid")
	b = stones(b, 90.0, "crumble", 5, 0.8, "island_flat")
	finish(b, "plates", 1, 1)
	var c := rings(S, 200.0, 3, "island_tall")
	c = carousel_hop(c, 205.0)
	finish(c, "bells", 1, 0)


func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l15_cloudsea", "Three shards, three routes. Find them all.")
