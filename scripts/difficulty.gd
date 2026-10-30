class_name Difficulty
## Easy / Normal / Hard (Settings "difficulty"): lives, the time challenge, how many fragments
## the fragment challenge needs, and how many enemies a level fields.

const NAMES := ["Easy", "Normal", "Hard"]


static func level() -> int:
	return int(Settings.get_v("difficulty"))


static func lives() -> int:
	return [5, 3, 2][level()]


static func par_scale() -> float:
	return [1.4, 1.0, 0.8][level()]


static func fragments_needed(total: int) -> int:
	return mini(total, 3) if level() == 0 else total


## Easy keeps every other enemy; Hard adds a guard wisp at each shard.
static func keep_enemy(index: int) -> bool:
	return level() != 0 or index % 2 == 0


static func extra_guards() -> bool:
	return level() == 2


static func describe(i: int) -> String:
	return ["5 lives, fewer enemies, relaxed time goals, 3 fragments earn the fragment star",
		"3 lives, the intended challenge",
		"2 lives, extra wisps guard every shard, tight time goals"][i]
