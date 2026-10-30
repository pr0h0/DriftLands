class_name SettingsMenu
extends PanelContainer
## Tabbed settings: gameplay, video, audio, controls (with key rebinding).

signal closed

var _waiting_action := ""
var _waiting_button: Button
var _key_buttons := {}


func _ready() -> void:
	theme = UITheme.get_theme()
	custom_minimum_size = Vector2(680, 560)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	v.add_child(UITheme.title_label("Settings", 46))
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)

	var g := _page(tabs, "Gameplay")
	_slider(g, "Look sensitivity" if Touch.active else "Mouse sensitivity", "mouse_sens", 0.2, 3.0, 0.05, "%.2f×")
	_check(g, "Invert vertical look", "invert_y")
	_slider(g, "Field of view", "fov", 60, 100, 1, "%d°")
	_check(g, "Auto-center camera while gliding", "camera_auto")
	_check(g, "Show hints", "hints")
	_check(g, "Compass toward remaining shards", "compass")
	var hl := OptionButton.new()
	for i in Settings.HUD_LAYOUTS.size():
		hl.add_item(Settings.HUD_LAYOUTS[i], i)
	hl.selected = int(Settings.get_v("hud_layout"))
	hl.item_selected.connect(func(i): Settings.set_v("hud_layout", i))
	_row(g, "HUD layout", hl)
	var df := OptionButton.new()
	for i in Difficulty.NAMES.size():
		df.add_item(Difficulty.NAMES[i], i)
	df.selected = Difficulty.level()
	df.tooltip_text = "\n".join(range(3).map(func(i): return "%s: %s" % [Difficulty.NAMES[i], Difficulty.describe(i)]))
	df.item_selected.connect(func(i): Settings.set_v("difficulty", i))
	_row(g, "Difficulty", df)
	var tc := OptionButton.new()
	for i in Settings.TOUCH_MODES.size():
		tc.add_item(Settings.TOUCH_MODES[i], i)
	tc.selected = int(Settings.get_v("touch_controls"))
	tc.tooltip_text = "Auto: on for phones and tablets, or after the first touch."
	tc.item_selected.connect(func(i): Settings.set_v("touch_controls", i))
	_row(g, "Touch controls", tc)
	_check(g, "Challenge mode (lives × 3 hearts, falls hurt)", "challenge")

	var vid := _page(tabs, "Video")
	var q := OptionButton.new()
	for i in Settings.QUALITY_NAMES.size():
		q.add_item(Settings.QUALITY_NAMES[i], i)
	q.selected = Settings.quality()
	q.item_selected.connect(func(i): Settings.set_v("quality", i))
	_row(vid, "Quality", q)
	_slider(vid, "Render scale", "render_scale", 0.5, 1.0, 0.05, "%d%%", 100.0)
	_check(vid, "Fullscreen", "fullscreen")
	if not OS.has_feature("web"):
		_check(vid, "V-Sync", "vsync")
	var note := Label.new()
	note.text = "Quality changes shadows, fog, ambient occlusion and grass density."
	note.modulate.a = 0.6
	note.add_theme_font_size_override("font_size", 16)
	vid.add_child(note)

	var a := _page(tabs, "Audio")
	_slider(a, "Master volume", "master", 0.0, 1.0, 0.01, "%d%%", 100.0)
	_slider(a, "Music", "music", 0.0, 1.0, 0.01, "%d%%", 100.0)
	_slider(a, "Effects", "sfx", 0.0, 1.0, 0.01, "%d%%", 100.0)

	var c := _page(tabs, "Controls")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 330
	c.add_child(scroll)
	var grid := VBoxContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for action in Settings.ACTIONS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 40)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_start_rebind.bind(action, b))
		_key_buttons[action] = b
		_row(grid, Settings.ACTIONS[action][0], b)
	var reset := UITheme.button("Reset controls to defaults", func(): Settings.reset_bindings(), 260)
	c.add_child(reset)
	_refresh_keys()
	Settings.changed.connect(_refresh_keys)

	var back := UITheme.button("Back", func(): closed.emit(), 160)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(back)


func _page(tabs: TabContainer, title: String) -> VBoxContainer:
	var m := MarginContainer.new()
	m.name = title
	m.add_theme_constant_override("margin_top", 16)
	tabs.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	return v


func _row(parent: Control, label: String, control: Control) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(control)
	parent.add_child(h)


func _slider(parent: Control, label: String, key: String, lo: float, hi: float, step: float, fmt: String, display_mul := 1.0) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_v(key))
	s.custom_minimum_size = Vector2(240, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := Label.new()
	val.custom_minimum_size.x = 64
	val.text = fmt % (s.value * display_mul)
	s.value_changed.connect(func(x): val.text = fmt % (x * display_mul); Settings.set_v(key, x))
	h.add_child(s)
	h.add_child(val)
	_row(parent, label, h)


func _check(parent: Control, label: String, key: String) -> void:
	var c := CheckBox.new()
	c.button_pressed = bool(Settings.get_v(key))
	c.toggled.connect(func(on): Settings.set_v(key, on))
	_row(parent, label, c)


func _start_rebind(action: String, b: Button) -> void:
	_waiting_action = action
	_waiting_button = b
	b.text = "press a key…"


func _refresh_keys() -> void:
	for action in _key_buttons:
		var keys: Array = Settings.bindings[action]
		_key_buttons[action].text = " / ".join(keys.map(func(k): return OS.get_keycode_string(k))) if not keys.is_empty() else "—"


func _input(event: InputEvent) -> void:
	if _waiting_action == "" or not (event is InputEventKey) or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	var key: int = event.physical_keycode
	if key == KEY_ESCAPE and _waiting_action != "pause":
		_waiting_action = ""
		_refresh_keys()
		return
	Settings.bind(_waiting_action, 0, key)
	_waiting_action = ""
	Sound.play("ui_click", -4.0)
