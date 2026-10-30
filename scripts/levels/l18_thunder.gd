extends LevelKit
## Thunderhead: built with the route kit (see level_kit.gd).


func _init() -> void:
	title = "Thunderhead"
	subtitle = "the storm has eyes"
	mood = "storm"
	sky = {"hour": 15.0, "paused": true, "storm": 1.0, "fog": 1.2, "allow_skip": false}
	palette = {"grass": "grass_storm", "rock": "rock_dark"}
	props = ["pine_a", "pine_b", "rock_c", "rock_a"]
	start_asset = "island_big"
	weather = "rain"
	pass


func plan() -> void:
	var a := rings(S, 0.0, 3, "island_tall")
	a = rings(a, 10.0, 2, "island_mid")
	finish(a, "free", 1, 2, true)
	var b := ferry(S, 120.0, "island_long")
	b = vent(b, 125.0, 16.0, "island_flat")
	finish(b, "plates", 2, 1)
	var c := vent(S, 240.0, 16.0, "island_mid")
	c = vent(c, 235.0, 16.0, "island_small_a")
	c = stones(c, 230.0, "crumble", 5, 0.8, "island_tall")
	finish(c, "bells", 1, 2)


func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l18_thunder", "Three shards, three routes. Find them all.")
