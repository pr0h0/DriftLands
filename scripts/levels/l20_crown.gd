extends LevelKit
## Frozen Crown: built with the route kit (see level_kit.gd).


func _init() -> void:
	title = "Frozen Crown"
	subtitle = "the last ice before the first light"
	mood = "frost"
	sky = {"hour": 22.0, "day_length": 4000.0, "allow_skip": false, "aurora": 1.0, "clouds": 0.25, "tint": Color(0.92, 0.97, 1.08)}
	palette = {"grass": "grass_snow", "rock": "rock_ice"}
	props = ["pine_a", "pine_b", "ice_spire", "ice_spire", "rock_c"]
	start_asset = "island_big"
	weather = "snow"
	prop_overrides = {"leaf": "leaf_snow"}


func plan() -> void:
	var a := stones(S, -90.0, "melt", 6, 0.6, "island_mid")
	a = causeway(a, -90.0, 2, "island_flat")
	a = stones(a, -85.0, "melt", 5, 0.8, "island_small_a")
	finish(a, "bells", 2, 1)
	var b := vent(S, 30.0, 18.0, "island_tall")
	b = rings(b, 35.0, 3, "island_mid")
	finish(b, "plates", 1, 2)
	var c := ferry(S, 150.0, "island_mid")
	c = elevator(c, 155.0, 16.0, "island_small_c")
	c = carousel_hop(c, 160.0)
	finish(c, "free", 2, 1)


func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l20_crown", "Three shards, three routes. Find them all.")
