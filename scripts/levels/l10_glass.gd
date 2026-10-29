extends LevelBase
## Glass Expanse (crystal night, chapter finale). East: lever causeway, then an echo path.
## North: moonstones by night to a sundial, then sunstones by day. West: a carousel to a
## seal that needs a split beam *and* three bells.

const S := Vector3(0, 0, 0)
const A1 := Vector3(70, -3, 0)
const A2 := Vector3(110, 2, 0)
const B1 := Vector3(0, 4, -56)
const B2 := Vector3(0, 9, -107)
const C := Vector3(-70, 0, 0)
const GLASS := {"grass": "grass_crystal", "rock": "rock_crystal"}


func _init() -> void:
	par_time = 600.0
	title = "Glass Expanse"
	subtitle = "every light, every bell, every path"
	mood = "glass"
	sky = {"hour": 23.0, "day_length": 4000.0, "allow_skip": false, "aurora": 0.6, "tint": Color(0.95, 0.9, 1.1)}
	spawn_point = Vector3(0, 1.5, 13)


func islands() -> void:
	biome = GLASS
	island("island_hub", S, 0.8, 24.0, GLASS)
	island("island_small_c", A1, 0.4, 5.5, GLASS)
	island("island_flat", A2, 1.2, 11.0, GLASS)
	island("island_east", B1, 1.0, 9.0, {"grass": "grass_crystal", "rock": "rock_crystal", "scale": 0.65})
	island("island_small_c", B2, 0.2, 5.5, GLASS)
	island("island_big", C, 0.0, 18.0, GLASS)
	island("island_small_a", Vector3(0, -2, 64), 0.3, 5.0, GLASS)
	secret_island("island_small_b", Vector3(35, -6, 40), 4.5)
	distant_islands(16, GLASS)


func layout() -> void:
	plaza_monolith(S)
	sundial(-7, 13, S.y)
	scatter(S, 15.0, 22.0, 12, ["crystals_a", "crystals_b", "dead_tree", "crystals_a", "rock_c"], 0.8, 1.4, true,
		[Vector3(24, 0, 6.0), Vector3(0, -24, 6.0), Vector3(-24, 0, 6.0), Vector3(0, 24, 6.0), Vector3(-7, 13, 4.0), Vector3(16, 4, 4.0)])
	var lan := FX.lanterns(Vector3(70, 12, 70), Color(0.75, 0.6, 1.0, 0.9), 110)
	add_child(lan)

	# --- East: causeway, then an echo path
	var cw := turning(causeway_pivot(S, Vector3.RIGHT), 90.0, 90.0)
	lever(16, 4, S.y, [cw])
	var ec := echo_path(Vector3(A1.x + 2, A1.y, A1.z + 1), stones_between(A1, A2))
	shrine_shard(A2.x + 2, A2.z, A2.y)
	sentinel(A2.x + 8, A2.z - 5, A2.y)
	wisp(Vector3(A2.x, A2.y + 3, A2.z + 3), 6.0)
	updraft(A2.x - 4.0, A2.z + 5.0, A2.y, 34.0)

	# --- North: moonstones -> sundial -> sunstones
	var nr := rim(S, Vector3.FORWARD).z
	for i in 3:
		phase(Vector3(sin(i * 1.2) * 1.2, 1.0 + i * 1.2, nr - 5.5 - i * 6.0), "night")
	wisp(Vector3(0, 4, -36), 4.5, true)
	sundial(B1.x, B1.z, B1.y)
	var b1r := rim(B1, Vector3.FORWARD).z
	for i in 5:
		phase(Vector3(sin(i * 1.1) * 1.2, B1.y + 0.8 + i * 0.8, b1r - 5.0 - i * 6.5), "day")
	shrine_shard(B2.x, B2.z, B2.y)
	updraft(B2.x + 2.0, B2.z + 3.0, B2.y, 30.0)

	# --- West: carousel -> split beam + bells seal
	carousel(Vector3(-40, -0.4, 0), 10.0, 4, 18.0)
	var c := C
	emitter(c.x - 5.5, c.z - 3.0, c.y, Vector3(c.x + 10, c.y, c.z - 3.0))
	mirror(c.x + 3.0, c.z - 3.0, c.y, 1)
	prism(c.x + 3.0, c.z + 2.0, c.y)
	var ra := receiver(c.x + 3.0, c.z + 6.0, c.y)
	var rb := receiver(c.x + 6.5, c.z + 2.0, c.y)
	var bells := [bell(c.x - 10, c.z + 8, c.y, 0.4), bell(c.x - 12, c.z - 6, c.y, 2.0), bell(c.x + 2, c.z - 12, c.y, 0.0)]
	cage(shrine_shard(c.x - 3.0, c.z + 3.0, c.y), [ra, rb] + bells)
	hint(Vector3(c.x, c.y + 1, c.z), 9.0, "glass_c", "This seal wants it all: both crystals lit, and all three bells ringing.")
	updraft(c.x - 8.0, c.z - 1.0, c.y, 30.0)
	_extras()


func _extras() -> void:
	secret_route(S, Vector3(35, -6, 40))
	mushroom_fragment(9, -12, S.y)
	fragment(Vector3(A2.x - 12, 32, A2.z + 5))
	var south := turning(causeway_pivot(S, Vector3.BACK), 0.0, 90.0)
	lever(-5, 19, S.y, [south])
	fragment(ground_pos(0, 64, -2.0) + Vector3(0, 1.3, 0))
	secret_route(Vector3(0, -2, 64), S)


func on_start() -> void:
	await get_tree().create_timer(6.0).timeout
	session.first_hint("l10", "The crystal heart of the Far Reaches. Everything you've learned, all at once.")
