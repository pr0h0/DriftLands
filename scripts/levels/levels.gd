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

## Modes outside the campaign (ids >= 100), see run_level.gd.
const MODES := {
	100: {"title": "Endless Flight", "sub": "How far can the wind carry you?", "mode": "endless", "theme": "meadow"},
	101: {"title": "Meadow Gates", "sub": "Time trial · eight hops through golden meadows", "mode": "trial", "theme": "meadow", "seed": 5101, "gold": 55.0},
	102: {"title": "Frost Run", "sub": "Time trial · ice, rings and updrafts", "mode": "trial", "theme": "frost", "seed": 5202, "gold": 55.0},
	103: {"title": "Ember Dash", "sub": "Time trial · ten hops over burning skies", "mode": "trial", "theme": "ember", "seed": 5303, "hops": 10, "gold": 85.0},
}

const CHAPTERS := {1: "Chapter I  ·  The Fading Light", 2: "Chapter II  ·  The Far Reaches", 3: "Chapter III  ·  The First Light"}


static func chapter_of(id: int) -> int:
	return int(LIST[id - 1].get("chapter", 1))


static func count() -> int:
	return LIST.size()


static func title_of(id: int) -> String:
	return MODES[id]["title"] if id >= 100 else LIST[id - 1]["title"]


static func make(id: int) -> LevelBase:
	if id >= 100:
		var m: Dictionary = MODES[id]
		var run := RunLevel.new()
		run.level_id = id
		run.configure(m["mode"], m["theme"], int(m.get("seed", randi() % 100000)))
		run.trial_hops = int(m.get("hops", 8))
		run.gold = float(m.get("gold", 0.0))
		run.title = m["title"]
		run.subtitle = m["sub"]
		run.lives = Difficulty.lives()
		return run
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
