extends LevelKit
## Gale Terraces: built with the route kit (see level_kit.gd).


func _init() -> void:
	title = "Gale Terraces"
	subtitle = "the wind never stops here"
	mood = "bright"
	sky = {"hour": 12.5, "day_length": 3000.0, "clouds": 0.55}
	palette = {}
	props = ["pine_a", "pine_b", "rock_c", "bush_b"]
	start_asset = "island_big"
	weather = ""
	nature = true


func plan() -> void:
	var a := rings(S, -80.0, 4, "island_mid")
	a = vent(a, -80.0, 14.0, "island_small_c")
	finish(a, "free", 1, 2, true)
	var b := vent(S, 40.0, 16.0, "island_tall")
	b = rings(b, 45.0, 3, "island_flat")
	finish(b, "bells", 2, 0)
	var c := causeway(S, 170.0, 1, "island_mid")
	c = causeway(c, 175.0, 2, "island_flat")
	finish(c, "plates", 1, 1)


func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l16_terraces", "Three shards, three routes. Find them all.")
