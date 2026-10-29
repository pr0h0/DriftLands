extends Node
## Player-facing settings, persisted to user://settings.cfg. Emits `changed` after any edit.

signal changed

const PATH := "user://settings.cfg"
const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra"]
const HUD_LAYOUTS := ["Top", "Side", "Bottom"]

## action -> [label, default physical keycodes]
const ACTIONS := {
	"move_forward": ["Move forward", [KEY_W, KEY_UP]],
	"move_back": ["Move back", [KEY_S, KEY_DOWN]],
	"move_left": ["Move left", [KEY_A, KEY_LEFT]],
	"move_right": ["Move right", [KEY_D, KEY_RIGHT]],
	"jump": ["Jump / glide", [KEY_SPACE]],
	"sprint": ["Run / dive", [KEY_SHIFT]],
	"interact": ["Interact", [KEY_E, KEY_F]],
	"block": ["Shield (hold)", [KEY_Q, KEY_C]],
	"respawn": ["Return to safe ground", [KEY_R]],
	"time_skip": ["Hurry time (tutorial)", [KEY_T]],
	"pause": ["Pause", [KEY_ESCAPE, KEY_P]],
	"photo": ["Photo mode", [KEY_F2]],
}

var values := {
	"mouse_sens": 1.0,
	"invert_y": false,
	"fov": 70.0,
	"camera_auto": true,
	"hints": true,
	"challenge": false,
	"compass": false,
	"hud_layout": 2,
	"master": 0.9,
	"music": 0.6,
	"sfx": 0.85,
	"quality": 1 if OS.has_feature("web") else 2,
	"fullscreen": false,
	"vsync": true,
	"render_scale": 1.0,
}
var bindings := {}  # action -> Array of keycodes


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in ACTIONS:
		bindings[a] = (ACTIONS[a][1] as Array).duplicate()
	_load()
	if OS.has_feature("web"):
		values["fullscreen"] = false  # browsers only allow fullscreen from a click/keypress
	_ensure_buses()
	apply_input()
	apply()


func get_v(key: String) -> Variant:
	return values[key]


func set_v(key: String, value: Variant) -> void:
	values[key] = value
	apply()
	save()
	changed.emit()


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


func toggle_fullscreen() -> void:
	set_v("fullscreen", not is_fullscreen())


func quality() -> int:
	return int(values["quality"])


## Grass/flower density multiplier for the current quality preset.
func grass_density() -> float:
	return [0.3, 0.6, 1.0, 1.4][quality()]


func bind(action: String, slot: int, keycode: int) -> void:
	var keys: Array = bindings[action]
	for a in bindings:  # a key may only drive one action
		bindings[a].erase(keycode)
	while keys.size() <= slot:
		keys.append(0)
	keys[slot] = keycode
	bindings[action] = keys.filter(func(k): return k != 0)
	apply_input()
	save()
	changed.emit()


func reset_bindings() -> void:
	for a in ACTIONS:
		bindings[a] = (ACTIONS[a][1] as Array).duplicate()
	apply_input()
	save()
	changed.emit()


func key_label(action: String) -> String:
	var keys: Array = bindings.get(action, [])
	if keys.is_empty():
		return "—"
	return OS.get_keycode_string(keys[0])


func apply_input() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.2)
		for k in bindings[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	var axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
	}
	for action in axes:
		var j := InputEventJoypadMotion.new()
		j.axis = axes[action][0]
		j.axis_value = axes[action][1]
		InputMap.action_add_event(action, j)
	for look in [["look_left", JOY_AXIS_RIGHT_X, -1.0], ["look_right", JOY_AXIS_RIGHT_X, 1.0],
			["look_up", JOY_AXIS_RIGHT_Y, -1.0], ["look_down", JOY_AXIS_RIGHT_Y, 1.0]]:
		if not InputMap.has_action(look[0]):
			InputMap.add_action(look[0], 0.2)
			var j := InputEventJoypadMotion.new()
			j.axis = look[1]
			j.axis_value = look[2]
			InputMap.action_add_event(look[0], j)
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("block", rmb)
	for b in [["jump", JOY_BUTTON_A], ["interact", JOY_BUTTON_X], ["sprint", JOY_BUTTON_RIGHT_SHOULDER], ["pause", JOY_BUTTON_START],
			["block", JOY_BUTTON_LEFT_SHOULDER]]:
		var e := InputEventJoypadButton.new()
		e.button_index = b[1]
		InputMap.action_add_event(b[0], e)


func _ensure_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	var music := AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(music) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.85
		rv.damping = 0.4
		rv.wet = 0.35
		rv.dry = 0.8
		AudioServer.add_bus_effect(music, rv)
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var rv2 := AudioEffectReverb.new()
		rv2.room_size = 0.6
		rv2.wet = 0.12
		AudioServer.add_bus_effect(sfx, rv2)


func apply() -> void:
	for pair in [["Master", "master"], ["Music", "music"], ["SFX", "sfx"]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx >= 0:
			var v: float = values[pair[1]]
			AudioServer.set_bus_volume_db(idx, linear_to_db(max(v, 0.0001)))
			AudioServer.set_bus_mute(idx, v <= 0.001)
	var vp := get_viewport()
	vp.scaling_3d_scale = float(values["render_scale"])
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality()]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality() < 2 else Viewport.SCREEN_SPACE_AA_DISABLED
	if not OS.has_feature("web"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values["vsync"] else DisplayServer.VSYNC_DISABLED)
	var want_fs: bool = values["fullscreen"]
	if want_fs != is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_fs else DisplayServer.WINDOW_MODE_WINDOWED)


func save() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	for a in bindings:
		cfg.set_value("bindings", a, bindings[a])
	cfg.set_value("migrations", "hud_bottom_default", true)
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in values:
		values[k] = cfg.get_value("settings", k, values[k])
	# One-time switch to the Bottom HUD (the new default) for settings saved before it existed.
	if not cfg.get_value("migrations", "hud_bottom_default", false):
		values["hud_layout"] = 2
	for a in bindings:
		var keys = cfg.get_value("bindings", a, bindings[a])
		if keys is Array:
			bindings[a] = keys
