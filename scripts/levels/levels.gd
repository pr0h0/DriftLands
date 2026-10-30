class_name Levels
## Level registry (ids are 1-based).

const LIST := [
	{"title": "The Monolith", "sub": "Tutorial · learn to walk, glide and ride the wind", "script": "res://scripts/levels/l1_monolith.gd"},
	{"title": "Windward Reach", "sub": "Boost rings, launch pads and chained updrafts", "script": "res://scripts/levels/l2_windward.gd"},
	{"title": "Lantern Night", "sub": "Day and night paths, mirrors, and things in the dark", "script": "res://scripts/levels/l3_lanterns.gd"},
	{"title": "Stormcrown", "sub": "Everything you've learned, inside the storm", "script": "res://scripts/levels/l4_stormcrown.gd"},
	{"title": "Shattered Spire", "sub": "Elevators, carousels and a bridge made of light", "script": "res://scripts/levels/l5_spire.gd"},
	{"title": "Eclipse Gardens", "sub": "Bend light across the void; trade night for day mid-flight", "script": "res://scripts/levels/l6_eclipse.gd"},
	{"title": "The Last Gale", "sub": "The longest flight. The fiercest storm.", "script": "res://scripts/levels/l7_gale.gd", "escape": true},
	{"title": "Frostveil", "sub": "Aurora skies, slippery ice and bridges that melt", "script": "res://scripts/levels/l8_frostveil.gd", "chapter": 2},
	{"title": "Sunken Sky", "sub": "Turn the old causeways; bend the desert sun", "script": "res://scripts/levels/l9_sunken.gd", "chapter": 2},
	{"title": "Glass Expanse", "sub": "Every light, every bell, every path", "script": "res://scripts/levels/l10_glass.gd", "chapter": 2},
	{"title": "Hanging Wilds", "sub": "A forest that climbed into the sky", "script": "res://scripts/levels/l11_wilds.gd", "chapter": 2},
	{"title": "Ashen Reach", "sub": "Crumbling stone under ember skies", "script": "res://scripts/levels/l12_ashen.gd", "chapter": 2},
	{"title": "Mirror Lake", "sub": "Light puzzles on still golden shores", "script": "res://scripts/levels/l13_mirror.gd", "chapter": 2},
	{"title": "Skyreach", "sub": "The tallest climb in the Far Reaches", "script": "res://scripts/levels/l14_skyreach.gd", "chapter": 2, "escape": true},
	{"title": "Cloudsea Ruins", "sub": "Low ruins at the edge of the clouds", "script": "res://scripts/levels/l15_cloudsea.gd", "chapter": 3},
	{"title": "Gale Terraces", "sub": "Ring gauntlets and twin causeways", "script": "res://scripts/levels/l16_terraces.gd", "chapter": 3},
	{"title": "Twilight Archipelago", "sub": "Paths that are half day, half night", "script": "res://scripts/levels/l17_twilight.gd", "chapter": 3},
	{"title": "Thunderhead", "sub": "Sentinels everywhere, rain in your eyes", "script": "res://scripts/levels/l18_thunder.gd", "chapter": 3},
	{"title": "Crystal Hollow", "sub": "Echoes, mirrors and night stones", "script": "res://scripts/levels/l19_hollow.gd", "chapter": 3},
	{"title": "Frozen Crown", "sub": "Melting paths under the aurora", "script": "res://scripts/levels/l20_crown.gd", "chapter": 3},
	{"title": "The First Beacon", "sub": "Every mechanic, every route, the final light", "script": "res://scripts/levels/l21_first.gd", "chapter": 3, "escape": true},
]

const CHAPTERS := {1: "Chapter I  ·  The Fading Light", 2: "Chapter II  ·  The Far Reaches", 3: "Chapter III  ·  The First Light"}


static func chapter_of(id: int) -> int:
	return int(LIST[id - 1].get("chapter", 1))


static func count() -> int:
	return LIST.size()


static func make(id: int) -> LevelBase:
	var lvl: LevelBase = load(LIST[id - 1]["script"]).new()
	lvl.level_id = id
	if LIST[id - 1].get("escape", false):
		lvl.escape = true
		lvl.par_time += 60.0
	return lvl


static func format_time(t: float) -> String:
	if t == INF or t <= 0.0:
		return "—"
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
