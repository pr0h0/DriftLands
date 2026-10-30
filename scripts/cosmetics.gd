class_name Cosmetics
## Wardrobe catalog: masks (unlocked by light fragments), scarves (by stars) and robes
## (by levels completed). Entries with "endless" (islands in one Endless Flight) or "golds"
## (trials won within gold time) unlock that way instead. The current choice lives in
## Progress.data["wardrobe"].

const MASKS := [
	{"id": "hidden", "name": "Hidden", "asset": "wanderer", "fragments": 0},
	{"id": "ritual", "name": "Ritual", "asset": "wanderer_ritual", "fragments": 15},
	{"id": "crescent", "name": "Crescent", "asset": "wanderer_crescent", "fragments": 45},
	{"id": "gale", "name": "Gale", "asset": "wanderer_gale", "endless": 85},
	{"id": "sunrise", "name": "Sunrise", "asset": "wanderer_sunrise", "golds": 3},
]

const SCARVES := [
	{"id": "ember", "name": "Ember", "base": Color(0.72, 0.16, 0.1), "glyph": Color(1.0, 0.78, 0.35), "stars": 0},
	{"id": "dawn", "name": "Dawn", "base": Color(0.88, 0.56, 0.14), "glyph": Color(1.0, 0.96, 0.75), "stars": 5},
	{"id": "sky", "name": "Sky", "base": Color(0.2, 0.46, 0.82), "glyph": Color(0.85, 0.96, 1.0), "stars": 10},
	{"id": "jade", "name": "Jade", "base": Color(0.1, 0.5, 0.36), "glyph": Color(0.88, 1.0, 0.7), "stars": 18},
	{"id": "dusk", "name": "Dusk", "base": Color(0.42, 0.18, 0.6), "glyph": Color(1.0, 0.7, 0.95), "stars": 27},
	{"id": "frost", "name": "Frost", "base": Color(0.86, 0.9, 0.96), "glyph": Color(0.35, 0.78, 1.0), "stars": 38},
	{"id": "night", "name": "Night", "base": Color(0.05, 0.05, 0.09), "glyph": Color(0.5, 0.92, 1.0), "stars": 50},
	{"id": "aurora", "name": "Aurora", "base": Color(0.12, 0.62, 0.55), "glyph": Color(0.85, 0.55, 1.0), "stars": 63},
	{"id": "tailwind", "name": "Tailwind", "base": Color(0.92, 0.94, 0.98), "glyph": Color(0.45, 0.75, 1.0), "endless": 25},
	{"id": "starlit", "name": "Starlit", "base": Color(0.08, 0.1, 0.28), "glyph": Color(1.0, 0.92, 0.55), "endless": 55},
]

const ROBES := [
	{"id": "crimson", "name": "Crimson", "a": Color(0.66, 0.15, 0.1), "b": Color(0.56, 0.11, 0.08), "levels": 0},
	{"id": "sand", "name": "Sand", "a": Color(0.78, 0.64, 0.42), "b": Color(0.68, 0.55, 0.35), "levels": 3},
	{"id": "moss", "name": "Moss", "a": Color(0.3, 0.42, 0.22), "b": Color(0.24, 0.35, 0.17), "levels": 7},
	{"id": "slate", "name": "Slate", "a": Color(0.3, 0.34, 0.42), "b": Color(0.24, 0.27, 0.34), "levels": 11},
	{"id": "ivory", "name": "Ivory", "a": Color(0.9, 0.87, 0.8), "b": Color(0.82, 0.78, 0.7), "levels": 14},
	{"id": "midnight", "name": "Midnight", "a": Color(0.1, 0.1, 0.2), "b": Color(0.07, 0.07, 0.14), "levels": 21},
	{"id": "skyrunner", "name": "Skyrunner", "a": Color(0.2, 0.52, 0.78), "b": Color(0.14, 0.42, 0.66), "endless": 40},
	{"id": "stormcloak", "name": "Stormcloak", "a": Color(0.36, 0.3, 0.5), "b": Color(0.26, 0.22, 0.38), "endless": 70},
]

const DEFAULT := {"mask": "hidden", "scarf": "ember", "robe": "crimson"}


static func current(slot: String) -> String:
	var w: Dictionary = Progress.data.get("wardrobe", {})
	return String(w.get(slot, DEFAULT[slot]))


static func choose(slot: String, id: String) -> void:
	var w: Dictionary = Progress.data.get("wardrobe", DEFAULT.duplicate())
	w[slot] = id
	Progress.data["wardrobe"] = w
	Progress.save()


static func catalog(slot: String) -> Array:
	match slot:
		"mask":
			return MASKS
		"scarf":
			return SCARVES
	return ROBES


static func _entry(slot: String, id: String) -> Dictionary:
	for e in catalog(slot):
		if e["id"] == id:
			return e
	return catalog(slot)[0]


## [have, need, unit] for an item's unlock requirement.
static func requirement(slot: String, e: Dictionary) -> Array:
	if e.has("endless"):
		return [Progress.endless_best(), int(e["endless"]), "Endless islands"]
	if e.has("golds"):
		return [Progress.trial_golds(), int(e["golds"]), "trial golds"]
	match slot:
		"mask":
			return [Progress.total_fragments(), int(e["fragments"]), "light fragments"]
		"scarf":
			return [Progress.total_stars(), int(e["stars"]), "stars"]
	return [Progress.levels_done(), int(e["levels"]), "levels completed"]


static func unlocked(slot: String, e: Dictionary) -> bool:
	var r := requirement(slot, e)
	return r[0] >= r[1]


## Names of everything currently unlocked, as "Name slot" (e.g. "Tailwind scarf").
static func unlocked_names() -> Array:
	var out := []
	for slot in ["mask", "scarf", "robe"]:
		for e in catalog(slot):
			if unlocked(slot, e):
				out.append("%s %s" % [e["name"], slot])
	return out


static func mask_asset() -> String:
	return String(_entry("mask", current("mask"))["asset"])


static func scarf_material(id := "") -> ShaderMaterial:
	var e := _entry("scarf", id if id != "" else current("scarf"))
	var m := (Mats.get_mat("scarf") as ShaderMaterial).duplicate() as ShaderMaterial
	m.set_shader_parameter("base_color", e["base"])
	m.set_shader_parameter("glyph_color", e["glyph"])
	return m


static func robe_material(id := "") -> Material:
	var e := _entry("robe", id if id != "" else current("robe"))
	if e["id"] == "crimson":
		return Mats.get_mat("cloth")
	return Mats.surface({"color_a": e["a"], "color_b": e["b"], "noise_scale": 4.0, "detail": 0.08, "roughness_value": 0.85})


## The Wanderer model dressed in the current (or given) wardrobe.
static func dress(model_root: Node, robe_id := "") -> void:
	var robe := robe_material(robe_id)
	for mi: MeshInstance3D in model_root.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src and src.resource_name == "cloth":
				mi.set_surface_override_material(i, robe)
