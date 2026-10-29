class_name Levels
## Level registry (ids are 1-based).

const LIST := [
	{"title": "The Monolith", "sub": "Tutorial · learn to walk, glide and ride the wind", "script": "res://scripts/levels/l1_monolith.gd"},
	{"title": "Windward Reach", "sub": "Boost rings, launch pads and chained updrafts", "script": "res://scripts/levels/l2_windward.gd"},
	{"title": "Lantern Night", "sub": "Day and night paths, mirrors, and things in the dark", "script": "res://scripts/levels/l3_lanterns.gd"},
	{"title": "Stormcrown", "sub": "Everything you've learned, inside the storm", "script": "res://scripts/levels/l4_stormcrown.gd"},
	{"title": "Shattered Spire", "sub": "Elevators, carousels and a bridge made of light", "script": "res://scripts/levels/l5_spire.gd"},
	{"title": "Eclipse Gardens", "sub": "Bend light across the void; trade night for day mid-flight", "script": "res://scripts/levels/l6_eclipse.gd"},
	{"title": "The Last Gale", "sub": "The longest flight. The fiercest storm.", "script": "res://scripts/levels/l7_gale.gd"},
	{"title": "Frostveil", "sub": "Aurora skies, slippery ice and bridges that melt", "script": "res://scripts/levels/l8_frostveil.gd", "chapter": 2},
	{"title": "Sunken Sky", "sub": "Turn the old causeways; bend the desert sun", "script": "res://scripts/levels/l9_sunken.gd", "chapter": 2},
	{"title": "Glass Expanse", "sub": "Every light, every bell, every path", "script": "res://scripts/levels/l10_glass.gd", "chapter": 2},
]

const CHAPTERS := {1: "Chapter I  ·  The Fading Light", 2: "Chapter II  ·  The Far Reaches"}


static func chapter_of(id: int) -> int:
	return int(LIST[id - 1].get("chapter", 1))


static func count() -> int:
	return LIST.size()


static func make(id: int) -> LevelBase:
	var lvl: LevelBase = load(LIST[id - 1]["script"]).new()
	lvl.level_id = id
	return lvl


static func format_time(t: float) -> String:
	if t == INF or t <= 0.0:
		return "—"
	return "%d:%02d" % [int(t) / 60, int(t) % 60]
