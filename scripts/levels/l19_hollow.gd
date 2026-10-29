extends LevelKit
## Crystal Hollow: built with the route kit (see level_kit.gd).


func _init() -> void:
	title = "Crystal Hollow"
	subtitle = "light sleeps inside the stone"
	mood = "glass"
	sky = {"hour": 23.5, "day_length": 4000.0, "allow_skip": false, "aurora": 0.4, "tint": Color(0.92, 0.9, 1.12)}
	palette = {"grass": "grass_crystal", "rock": "rock_crystal"}
	props = ["crystals_a", "crystals_b", "dead_tree", "rock_c"]
	start_asset = "island_hub"
	weather = ""
	pass


func plan() -> void:
	var a := stones(S, -60.0, "echo", 7, 0.4, "island_flat")
	a = carousel_hop(a, -55.0)
	finish(a, "bells", 2, 0)
	var b := causeway(S, 60.0, 2, "island_big")
	finish(b, "mirror", 1, 1)
	var c := elevator(S, 180.0, 14.0, "island_mid")
	c = stones(c, 185.0, "night", 6, 0.8, "island_small_c")
	c = vent(c, 190.0, 12.0, "island_tall")
	finish(c, "plates", 2, 1)


func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l19_hollow", "Three shards, three routes. Find them all.")
