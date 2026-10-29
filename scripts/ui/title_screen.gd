class_name TitleScreen
extends Node3D
## Main menu over a slowly orbiting view of the first island.

signal start_level(id: int, resume: bool)

var cycle: SkyCycle
var level: LevelBase
var cam: Camera3D
var _t := 0.0
var _ui: Control
var _menu: VBoxContainer
var _pages: Control
var _settings: SettingsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	cycle = SkyCycle.new()
	cycle.hour = 17.6
	cycle.day_length = 4000.0
	cycle.add_to_group("title_cycle")
	add_child(cycle)
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 3000
	add_child(cam)
	cam.make_current()
	_orbit(0.0)
	_build_ui()
	Sound.music("menu")
	level = Levels.make(1)
	level.cycle = cycle
	level.decor_only = true
	add_child(level)
	await level.build()


func _process(dt: float) -> void:
	_t += dt
	_orbit(_t)
	if level:
		level.follow = cam


## Secret: typing "skyward" on the title screen unlocks every level (for testing).
const UNLOCK_CODE := "skyward"
var _typed := ""


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.unicode > 0:
		_typed = (_typed + char(event.unicode).to_lower()).right(UNLOCK_CODE.length())
		if _typed == UNLOCK_CODE:
			_typed = ""
			Progress.data["unlocked"] = Levels.count()
			Progress.save()
			Sound.play("collect")
			var l := UITheme.title_label("All levels unlocked", 40)
			l.modulate = UITheme.GOLD
			l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
			l.position = Vector2(_ui.size.x / 2.0 - 200.0, 40.0)
			_ui.add_child(l)
			var t := create_tween()
			t.tween_interval(2.0)
			t.tween_property(l, "modulate:a", 0.0, 1.0)
			t.tween_callback(l.queue_free)
			_show_main()


func _orbit(t: float) -> void:
	var a := 2.4 + t * 0.03
	cam.global_position = Vector3(cos(a) * 49.0, 16.0 + sin(t * 0.1) * 2.5, sin(a) * 49.0)
	cam.look_at(Vector3(0, 4, 0))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.theme = UITheme.get_theme()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.04, 0.03, 0.06, 0.88))
	g.set_color(1, Color(0.04, 0.03, 0.06, 0.0))
	g.add_point(0.55, Color(0.04, 0.03, 0.06, 0.6))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 1150
	_ui.add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 110)
	margin.add_theme_constant_override("margin_top", 90)
	margin.add_theme_constant_override("margin_bottom", 70)
	_ui.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)
	col.add_child(UITheme.title_label("Driftlands", 112))
	var sub := Label.new()
	sub.text = "carry the light home"
	sub.modulate = Color(1, 1, 1, 0.9)
	sub.add_theme_font_size_override("font_size", 22)
	col.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	col.add_child(spacer)
	_pages = Control.new()
	_pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_pages)
	_show_main()


func _clear_pages() -> void:
	for c in _pages.get_children():
		c.queue_free()


## A solid backing panel for sub-pages so text stays readable over the 3D backdrop.
func _panel_page() -> VBoxContainer:
	var p := PanelContainer.new()
	_pages.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return v


func _show_main() -> void:
	_clear_pages()
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 8)
	_pages.add_child(_menu)
	var cp := Progress.checkpoint()
	if not cp.is_empty():
		var id := int(cp["level"])
		_menu.add_child(UITheme.button("Continue  ·  " + Levels.LIST[id - 1]["title"], func(): start_level.emit(id, true)))
	elif Progress.unlocked() > 1:
		var nid: int = min(Progress.unlocked(), Levels.count())
		_menu.add_child(UITheme.button("Continue  ·  " + Levels.LIST[nid - 1]["title"], func(): start_level.emit(nid, false)))
	_menu.add_child(UITheme.button("New game", _new_game))
	_menu.add_child(UITheme.button("Chapters", _show_chapters))
	_menu.add_child(UITheme.button("Settings", _show_settings))
	_menu.add_child(UITheme.fullscreen_button())
	if not OS.has_feature("web"):
		_menu.add_child(UITheme.button("Quit", func(): get_tree().quit()))
	(_menu.get_child(0) as Button).grab_focus()


func _new_game() -> void:
	if not Progress.has_progress():
		start_level.emit(1, false)
		return
	_clear_pages()
	var v := _panel_page()
	var l := Label.new()
	l.text = "Start over? Your unlocked chapters and best times will be erased."
	v.add_child(l)
	v.add_child(UITheme.button("Yes, start a new game", func(): Progress.reset(); start_level.emit(1, false)))
	v.add_child(UITheme.button("Cancel", _show_main))


func _show_chapters() -> void:
	_clear_pages()
	var v := _panel_page()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var outer := v
	v = list
	var last_ch := 0
	for i in Levels.count():
		var id := i + 1
		var ch := Levels.chapter_of(id)
		if ch != last_ch:
			last_ch = ch
			var hl := UITheme.title_label(Levels.CHAPTERS[ch], 30)
			hl.modulate = UITheme.GOLD
			v.add_child(hl)
		var info := Progress.level_info(id)
		var locked := id > Progress.unlocked()
		var text := "%d.  %s" % [id, Levels.LIST[i]["title"]]
		if locked:
			text += "   ·  locked"
		elif info.get("done", false):
			text += "   ·  best %s  ·  fragments %d/5" % [Levels.format_time(float(info.get("best", 0))), Progress.fragments(id).size()]
		var b := UITheme.button(text, func(): start_level.emit(id, false), 640)
		if info.get("done", false):
			var chal: Dictionary = info.get("challenges", {})
			var sr := StarRow.new().setup([chal.get("flawless", false), chal.get("time", false), chal.get("fragments", false)], 12.0)
			var w := sr.custom_minimum_size.x
			var h := sr.custom_minimum_size.y
			sr.anchor_left = 1.0
			sr.anchor_right = 1.0
			sr.anchor_top = 0.5
			sr.anchor_bottom = 0.5
			sr.offset_left = -w - 14.0
			sr.offset_right = -14.0
			sr.offset_top = -h / 2.0
			sr.offset_bottom = h / 2.0
			b.add_child(sr)
		b.disabled = locked
		v.add_child(b)
		var d := Label.new()
		d.text = "     " + Levels.LIST[i]["sub"]
		d.modulate = Color(1, 0.94, 0.86, 0.6 if locked else 0.88)
		d.add_theme_font_size_override("font_size", 16)
		v.add_child(d)
	outer.add_child(UITheme.button("Back", _show_main))


func _show_settings() -> void:
	_clear_pages()
	_settings = SettingsMenu.new()
	_settings.closed.connect(_show_main)
	_pages.add_child(_settings)
