class_name LoreStone
extends Node3D
## A carved tablet near the beacon. Reading it shows a page of the story and adds it to the Journal.

var level_id := 1
var _rune: StandardMaterial3D
var _light: OmniLight3D


func _ready() -> void:
	add_to_group("interactable")
	var model := Assets.spawn("lore_stone", true, 2)
	add_child(model)
	_rune = ElUtil.unique_mat(model, "rune") as StandardMaterial3D
	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.88, 1.0)
	_light.omni_range = 4.0
	_light.position = Vector3(0, 1.4, 0)
	add_child(_light)
	_set_read(level_id in Progress.data.get("lore", []))


func _set_read(read: bool) -> void:
	_rune.emission_energy_multiplier = 1.2 if read else 4.0
	_light.light_energy = 0.4 if read else 1.4


func interact_prompt() -> String:
	return "Read the stone"


func interact() -> void:
	var first: bool = not level_id in Progress.data.get("lore", [])
	Progress.add_lore(level_id)
	Sound.play_at("lore", global_position, -2.0)
	get_tree().call_group("hud", "show_lore", Lore.title_of(level_id), Lore.text_of(level_id), first)
	_set_read(true)
