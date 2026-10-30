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
var _margin: MarginContainer
var _header: VBoxContainer
var _settings: SettingsMenu
var wanderer: TitleWanderer
var _wardrobe := false
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _preview := {}


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
	wanderer = TitleWanderer.new()
	wanderer.center = level.monolith.global_position
	wanderer.position = wanderer.center + Vector3(2.0, 1.0, 7.0)
	add_child(wanderer)
	_grow_home()


func _process(dt: float) -> void:
	_t += dt
	_orbit(_t, dt)
	if level:
		level.follow = cam


## The title island grows with the player's progress: plaza lights, monolith runes, flowers,
## butterflies, the beacon beam, birds, a garden islet and, at the very end, a golden sky.
func _grow_home() -> void:
	var done := Progress.levels_done()
	var c := level.monolith.global_position
	level.wake_posts(done)
	for ch in [1, 2, 3]:
		if Progress.chapter_done(ch):
			level.light_runes(ch - 1)
	if done >= 3:
		level._bloom_flowers(c)
	if done >= 5:
		var bf := FX.butterflies(Vector3(12, 1.5, 12))
		bf.position = c + Vector3(0, 2, 0)
		level.add_child(bf)
		var lan := FX.lanterns(Vector3(16, 3, 16), Color(1.0, 0.85, 0.55, 0.9), 40 + done * 4)
		lan.position = c + Vector3(0, 3, 0)
		level.add_child(lan)
	if Progress.chapter_done(1):
		var top := Node3D.new()
		top.position = Vector3(0, 8.6, 0)
		level.monolith.add_child(top)
		var gold := Progress.chapter_done(3)
		top.add_child(FX.beam(1.0, 600.0, Color(1.0, 0.85, 0.5) if gold else Color(0.6, 0.9, 1.0), 2.5))
	if done >= 10:
		level.birds(c + Vector3(0, 24, 0), 10, 32.0)
	if Progress.chapter_done(2):
		var p := Vector3(-30, 9, -34)
		level.island("island_small_c", p, 0.8, 5.5, {"flowers": true})
		await get_tree().physics_frame
		await get_tree().physics_frame
		level._grass(level._islands[-1])
		level.put("tree_blossom", p.x, p.z, p.y, 0.3, 1.1)
		var edge := level.rim(p, Vector3(0.6, 0, 0.8), 0.4)
		level.waterfall(edge.x, edge.z, edge.y, Vector3(0.6, 0, 0.8), 50.0)


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


## Slow orbit framing the island and the Wanderer; the wardrobe swings in for a close-up.
func _orbit(t: float, dt := 0.0) -> void:
	var a := 2.4 + t * 0.03
	var pos := Vector3(cos(a) * 31.0, 11.0 + sin(t * 0.1) * 2.0, sin(a) * 31.0)
	var look := Vector3(0, 3, 0)
	if wanderer:
		var w := wanderer.global_position
		look = look.lerp(w + Vector3.UP, 0.6)
		pos += (w - Vector3(0, w.y, 0)) * 0.5
		if _wardrobe:
			var out := Vector3(cos(a), 0, sin(a))
			pos = w + out * 3.6 + Vector3.UP * 1.5
			var right := (-out).cross(Vector3.UP)
			look = w + Vector3.UP * 1.0 - right * 0.9
			wanderer.face_target = pos
	if dt == 0.0:
		_cam_pos = pos
		_cam_look = look
	else:
		var k := 1.0 - exp(-(3.0 if _wardrobe else 1.5) * dt)
		_cam_pos = _cam_pos.lerp(pos, k)
		_cam_look = _cam_look.lerp(look, k)
	cam.global_position = _cam_pos
	cam.look_at(_cam_look)


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

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_margin.add_child(col)
	_header = VBoxContainer.new()
	_header.add_theme_constant_override("separation", 6)
	col.add_child(_header)
	_header.add_child(UITheme.title_label("Driftlands", 112))
	var sub := Label.new()
	sub.text = "carry the light home"
	sub.modulate = Color(1, 1, 1, 0.9)
	sub.add_theme_font_size_override("font_size", 22)
	_header.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	_header.add_child(spacer)
	_fit_screen()
	Touch.toggled.connect(func(_on): _fit_screen())
	var tip := Touch.home_screen_tip()
	if tip != "":
		var tl := Label.new()
		tl.text = tip
		tl.add_theme_font_size_override("font_size", 22)
		tl.add_theme_color_override("font_color", UITheme.GOLD)
		tl.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.08, 0.9))
		tl.add_theme_constant_override("outline_size", 8)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		tl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		tl.grow_vertical = Control.GROW_DIRECTION_BEGIN
		tl.offset_right = -24
		tl.offset_bottom = -16
		_ui.add_child(tl)
	_pages = Control.new()
	_pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_pages)
	_show_main()


## Phones (touch UI, 720 logical px tall): tighter margins, a smaller title, and sub-pages
## hide the title so the taller panels (settings, chapters) fit on screen.
func _fit_screen() -> void:
	var compact := Touch.active
	_margin.add_theme_constant_override("margin_left", 60 if compact else 110)
	_margin.add_theme_constant_override("margin_top", 24 if compact else 90)
	_margin.add_theme_constant_override("margin_bottom", 20 if compact else 70)
	(_header.get_child(0) as Label).label_settings.font_size = 76 if compact else 112
	_header.get_child(2).custom_minimum_size.y = 14 if compact else 40


func _clear_pages() -> void:
	_header.visible = true
	for c in _pages.get_children():
		c.queue_free()
	if _wardrobe:
		_wardrobe = false
		wanderer.posing = false
		wanderer.redress()


## A solid backing panel for sub-pages so text stays readable over the 3D backdrop.
func _panel_page() -> VBoxContainer:
	_header.visible = not Touch.active
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
	_menu.add_child(UITheme.button("Endless & Trials", _show_modes))
	_menu.add_child(UITheme.button("Wardrobe", _show_wardrobe))
	_menu.add_child(UITheme.button("Journal", _show_journal))
	_menu.add_child(UITheme.button("Settings", _show_settings))
	if not OS.has_feature("web_ios"):  # iPhone browsers have no fullscreen (see the home-screen tip)
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
	_header.visible = not Touch.active
	_settings = SettingsMenu.new()
	_settings.closed.connect(_show_main)
	_pages.add_child(_settings)


# ------------------------------------------------------------ wardrobe

func _show_wardrobe() -> void:
	_clear_pages()
	_wardrobe = true
	wanderer.posing = true
	_preview = {"mask": Cosmetics.current("mask"), "scarf": Cosmetics.current("scarf"), "robe": Cosmetics.current("robe")}
	var v := _panel_page()
	v.add_child(UITheme.title_label("Wardrobe", 40))
	var stats := Label.new()
	stats.text = "%d / 63 stars  ·  %d / 105 fragments  ·  %d / %d levels" % [Progress.total_stars(), Progress.total_fragments(), Progress.levels_done(), Levels.count()]
	stats.modulate = Color(1, 0.94, 0.86, 0.85)
	stats.add_theme_font_size_override("font_size", 17)
	v.add_child(stats)
	for slot in ["mask", "scarf", "robe"]:
		_wardrobe_row(v, slot)
	v.add_child(UITheme.button("Back", _show_main, 200))


func _wardrobe_row(v: VBoxContainer, slot: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var name_l := Label.new()
	name_l.text = {"mask": "Mask", "scarf": "Scarf", "robe": "Robe"}[slot]
	name_l.custom_minimum_size.x = 80
	row.add_child(name_l)
	var item := Label.new()
	item.custom_minimum_size.x = 300
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var note := Label.new()
	note.add_theme_font_size_override("font_size", 15)
	note.custom_minimum_size.x = 120
	var refresh := func():
		var cat := Cosmetics.catalog(slot)
		var e: Dictionary = cat.filter(func(x): return x["id"] == _preview[slot])[0]
		var r := Cosmetics.requirement(slot, e)
		var ok := Cosmetics.unlocked(slot, e)
		item.text = e["name"] if ok else "%s  ·  %d / %d %s" % [e["name"], r[0], r[1], r[2]]
		item.modulate = Color.WHITE if ok else Color(1, 0.75, 0.7, 0.8)
		note.text = "worn" if ok else "locked"
		note.modulate = UITheme.GOLD if ok else Color(1, 1, 1, 0.5)
		if ok:
			Cosmetics.choose(slot, e["id"])
		wanderer.redress(_preview["mask"], _preview["scarf"], _preview["robe"])
	var step := func(d: int):
		var cat := Cosmetics.catalog(slot)
		var i := 0
		for k in cat.size():
			if cat[k]["id"] == _preview[slot]:
				i = k
		_preview[slot] = cat[(i + d + cat.size()) % cat.size()]["id"]
		Sound.play("gate", -10.0, 1.4)
		refresh.call()
	row.add_child(UITheme.button("<", func(): step.call(-1), 48))
	row.add_child(item)
	row.add_child(UITheme.button(">", func(): step.call(1), 48))
	row.add_child(note)
	refresh.call()


# ------------------------------------------------------------ journal

func _show_journal() -> void:
	_clear_pages()
	var v := _panel_page()
	var found: Array = Progress.data.get("lore", [])
	var head := UITheme.title_label("Journal", 40)
	v.add_child(head)
	var count := Label.new()
	count.text = "%d / %d pages found  ·  read the carved stone near each beacon" % [found.size(), Lore.ENTRIES.size()]
	count.modulate = Color(1, 0.94, 0.86, 0.8)
	count.add_theme_font_size_override("font_size", 16)
	v.add_child(count)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var last_ch := 0
	for id in range(1, Levels.count() + 1):
		var ch := Levels.chapter_of(id)
		if ch != last_ch:
			last_ch = ch
			var hl := UITheme.title_label(Levels.CHAPTERS[ch], 26)
			hl.modulate = UITheme.GOLD
			list.add_child(hl)
		var t := Label.new()
		var have: bool = id in found
		t.text = "%s   ·   %s" % [Lore.title_of(id) if have else "Unread page", Levels.LIST[id - 1]["title"] if id <= Progress.unlocked() else "?"]
		t.add_theme_font_size_override("font_size", 19)
		t.modulate = Color.WHITE if have else Color(1, 1, 1, 0.45)
		list.add_child(t)
		if have:
			var body := Label.new()
			body.text = Lore.text_of(id)
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.custom_minimum_size.x = 660
			body.modulate = Color(1, 0.94, 0.86, 0.85)
			body.add_theme_font_size_override("font_size", 16)
			list.add_child(body)
	v.add_child(UITheme.button("Back", _show_main, 200))


# ------------------------------------------------------------ endless + trials

func _show_modes() -> void:
	_clear_pages()
	var v := _panel_page()
	v.add_child(UITheme.title_label("Endless & Trials", 40))
	var runs: Dictionary = Progress.data.get("runs", {})
	for id in Levels.MODES:
		var m: Dictionary = Levels.MODES[id]
		var rec: Dictionary = runs.get("endless" if m["mode"] == "endless" else "trial_%d" % id, {})
		var best := ""
		if rec.has("best"):
			best = "   ·  best %d islands" % int(rec["best"]) if m["mode"] == "endless" else "   ·  best %s" % Levels.format_time(float(rec["best"]))
		v.add_child(UITheme.button("%s%s" % [m["title"], best], func(): start_level.emit(id, false), 640))
		var d := Label.new()
		d.text = "     " + m["sub"]
		d.modulate = Color(1, 0.94, 0.86, 0.85)
		d.add_theme_font_size_override("font_size", 16)
		v.add_child(d)
	var note := Label.new()
	note.text = "Difficulty (Settings) sets your falls in Endless Flight."
	note.modulate = Color(1, 1, 1, 0.55)
	note.add_theme_font_size_override("font_size", 15)
	v.add_child(note)
	v.add_child(UITheme.button("Back", _show_main, 200))
