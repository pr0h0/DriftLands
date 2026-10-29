extends LevelBase
## Frostveil (night, aurora, snow). East: melting ice stones to a frozen lake (slippery).
## North: a lever turns the old causeway (two pulls) toward a bell-sealed shard.
## West: a wind vent to an icy spire guarded by wisps.

const S := Vector3(0, 0, 0)
const A := Vector3(60, -2, 0)
const B := Vector3(0, -3, -64)
const C := Vector3(-70, 12, 8)
const SNOW := {"grass": "grass_snow", "rock": "rock_ice"}


func _init() -> void:
	par_time = 480.0
	title = "Frostveil"
	subtitle = "where the light sleeps under ice"
	mood = "frost"
	sky = {"hour": 21.5, "day_length": 4000.0, "allow_skip": false, "aurora": 1.0, "clouds": 0.25, "tint": Color(0.92, 0.97, 1.08)}
	spawn_point = Vector3(0, 1.5, 11)
	prop_overrides = {"leaf": "leaf_snow"}


func islands() -> void:
	biome = SNOW
	island("island_big", S, 0.4, 18.0, SNOW)
	island("island_flat", A, 0.9, 11.0, {"grass": "grass_snow", "rock": "rock_ice", "ice": true})
	island("island_mid", B, 1.7, 10.0, SNOW)
	island("island_tall", C, 0.2, 9.0, {"grass": "grass_snow", "rock": "rock_ice", "ice": true})
	secret_island("island_small_b", Vector3(35, -6, 40), 4.5)
	island("island_small_c", Vector3(-30.5, 0, 40.6), 0.8, 5.5, SNOW)
	distant_islands(16, SNOW)


func layout() -> void:
	plaza_monolith(S)
	scatter(S, 11.0, 16.5, 9, ["pine_a", "pine_b", "pine_a", "ice_spire", "rock_c"], 0.8, 1.2, true,
		[Vector3(18, 0, 5.0), Vector3(0, -15, 6.0), Vector3(-15, 3, 6.0), Vector3(0, 11, 3.0), Vector3(4, -12, 3.0)])
	var holder := Node3D.new()
	holder.add_child(FX.snow([400, 700, 1100, 1500][Settings.quality()]))
	follow_fx(holder)

	# --- East: melting ice stones to the frozen lake
	for p in stones_between(S, A):
		crumble(p, "ice")
	hint(rim(S, Vector3.RIGHT) + Vector3(-2, 1, 0), 5.0, "melt", "Ice stones melt under your feet. Keep moving!")
	hint(A + Vector3(0, 1, 0), 9.0, "ice", "The lake is frozen solid, and slippery. Mind your momentum.")
	shrine_shard(A.x + 6.0, A.z, A.y)
	wisp(Vector3(A.x, A.y + 3, A.z), 7.0)
	updraft(A.x - 5.0, A.z + 4.0, A.y, 30.0)
	for k in 5:
		var p := polar(A, k * 1.3 + 0.4, 9.5)
		put("ice_spire", p.x, p.y, A.y, rng.randf() * TAU, rng.randf_range(0.8, 1.6))

	# --- North: the old causeway, two pulls to line it up
	var cw := turning(causeway_pivot(S, Vector3.FORWARD), 0.0, 45.0)
	lever(4, -12, S.y, [cw])
	hint(Vector3(4, 1, -12), 4.0, "cw", "The causeway is out of line. Pull the lever until it points the way.")
	var bells := [bell(B.x - 4.0, B.z - 2.0, B.y, 0.4), bell(B.x + 4.0, B.z - 2.0, B.y, 2.8)]
	cage(shrine_shard(B.x, B.z - 5.0, B.y), bells)
	updraft(B.x + 6.0, B.z - 3.0, B.y, 30.0)
	scatter(B, 6.0, 9.5, 5, ["pine_b", "ice_spire", "rock_a"], 0.8, 1.2, true, [Vector3(B.x + 6, B.z - 3, 5.5), Vector3(0, B.z + 8, 4.0)])

	# --- West: vent to the icy spire
	var u := rim(S, Vector3.LEFT, 4.0)
	updraft(u.x, u.z, S.y, 32.0)
	shrine_shard(C.x - 3.0, C.z - 2.0, C.y)
	wisp(Vector3(C.x, C.y + 3, C.z), 6.0)
	wisp(Vector3(C.x + 4, C.y + 5, C.z - 6), 5.0)
	updraft(C.x + 3.0, C.z + 3.0, C.y, 20.0)
	_extras()


func _extras() -> void:
	secret_route(S, Vector3(35, -6, 40))
	mushroom_fragment(-9, -6, S.y)
	fragment(Vector3(A.x - 12, 24, A.z + 4))
	var echo_pts := stones_between(S, Vector3(-30.5, 0, 40.6))
	echo_path(rim(S, Vector3(-30.5, 0, 40.6).normalized(), 3.0), echo_pts)
	fragment(ground_pos(-30.5, 40.6, 0.0) + Vector3(0, 1.3, 0))
	secret_route(Vector3(-30.5, 0, 40.6), S)


func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l8", "Chapter II. East over melting ice, north by the old causeway, west on the wind.")
