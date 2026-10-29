extends Node
## Save data: unlocked levels, best times, and a mid-level checkpoint. Stored as user://save.json.

const PATH := "user://save.json"

var data := {"unlocked": 1, "levels": {}, "checkpoint": {}}


func _ready() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			for k in data:
				if parsed.has(k):
					data[k] = parsed[k]


func save() -> void:
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


func has_progress() -> bool:
	return unlocked() > 1 or not checkpoint().is_empty()


func reset() -> void:
	data = {"unlocked": 1, "levels": {}, "checkpoint": {}}
	save()
