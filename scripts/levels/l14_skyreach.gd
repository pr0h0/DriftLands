extends LevelKit
## Skyreach: built with the route kit (see level_kit.gd).


func _init() -> void:
	title = "Skyreach"
	subtitle = "the tallest tower of islands in the Far Reaches"
	mood = "frost"
	sky = {"hour": 16.0, "day_length": 3000.0, "clouds": 0.35, "aurora": 0.3}
	palette = {"grass": "grass_snow", "rock": "rock_ice"}
	props = ["pine_a", "pine_b", "ice_spire", "rock_c"]
	start_asset = "island_big"
	weather = "snow"
	prop_overrides = {"leaf": "leaf_snow"}


func plan() -> void:
	var a := elevator(S, -90.0, 14.0, "island_mid")
	a = vent(a, -95.0, 16.0, "island_small_c")
	a = carousel_hop(a, -100.0)
	a = vent(a, -105.0, 14.0, "island_tall")
	finish(a, "bells", 2, 1)
	var b := causeway(S, 30.0, 2, "island_flat")
	b = stones(b, 35.0, "melt", 5, 1.0, "island_flat")
	finish(b, "plates", 1, 0)
	var c := rings(S, 150.0, 3, "island_mid")
	c = vent(c, 155.0, 14.0, "island_small_c")
	finish(c, "free", 1, 1)


func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l14_skyreach", "Three shards, three routes. Find them all.")
