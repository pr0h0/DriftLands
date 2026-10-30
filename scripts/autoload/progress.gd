extends Node
## Save data: unlocked levels, best times, and a mid-level checkpoint. Stored as user://save.json.

const PATH := "user://save.json"

var readonly := false  ## debug runs with fake progress never write the save

var data := {"unlocked": 1, "levels": {}, "checkpoint": {}, "wardrobe": {}, "lore": [], "runs": {}}


func _ready() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			for k in data:
				if parsed.has(k):
					data[k] = parsed[k]


func save() -> void:
	if readonly:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


func unlocked() -> int:
	return int(data["unlocked"])


func level_info(id: int) -> Dictionary:
	return data["levels"].get(str(id), {})


func complete(id: int, time: float) -> bool:
	var info := level_info(id)
	var best := time < float(info.get("best", INF))
	info["done"] = true
	info["best"] = min(time, float(info.get("best", INF)))
	data["levels"][str(id)] = info
	data["unlocked"] = max(unlocked(), id + 1)
	data["checkpoint"] = {}
	save()
	return best


func fragments(id: int) -> Array:
	return level_info(id).get("fragments", [])


func add_fragment(id: int, idx: int) -> void:
	var info := level_info(id)
	var f: Array = info.get("fragments", [])
	if not idx in f:
		f.append(idx)
	info["fragments"] = f
	data["levels"][str(id)] = info
	save()


## Records challenge results (only ever upgrades). Returns the merged dict.
func record_challenges(id: int, done: Dictionary) -> Dictionary:
	var info := level_info(id)
	var ch: Dictionary = info.get("challenges", {})
	for k in done:
		ch[k] = ch.get(k, false) or done[k]
	info["challenges"] = ch
	data["levels"][str(id)] = info
	save()
	return ch


func set_checkpoint(id: int, shards: Array, pos: Vector3, time: float, lives := 3) -> void:
	data["checkpoint"] = {"level": id, "shards": shards, "pos": [pos.x, pos.y, pos.z], "time": time, "lives": lives}
	save()


func checkpoint() -> Dictionary:
	return data["checkpoint"]


func clear_checkpoint() -> void:
	data["checkpoint"] = {}
	save()


func levels_done() -> int:
	var n := 0
	for k in data["levels"]:
		if data["levels"][k].get("done", false) and int(k) < 100:
			n += 1
	return n


func total_stars() -> int:
	var n := 0
	for k in data["levels"]:
		if int(k) >= 100:
			continue
		for v in data["levels"][k].get("challenges", {}).values():
			n += 1 if v else 0
	return n


func total_fragments() -> int:
	var n := 0
	for k in data["levels"]:
		n += (data["levels"][k].get("fragments", []) as Array).size()
	return n


## Chapter `ch` counts as complete when all of its levels are done.
func chapter_done(ch: int) -> bool:
	for i in Levels.count():
		if Levels.chapter_of(i + 1) == ch and not level_info(i + 1).get("done", false):
			return false
	return true


func has_progress() -> bool:
	return unlocked() > 1 or not checkpoint().is_empty()


func reset() -> void:
	# The wardrobe choice and endless/trial records survive a new game.
	data = {"unlocked": 1, "levels": {}, "checkpoint": {}, "wardrobe": data.get("wardrobe", {}), "lore": [], "runs": data.get("runs", {})}
	save()
