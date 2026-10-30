class_name Hud
extends CanvasLayer
## In-game HUD. Three layouts (Top / Side / Bottom, see Settings "hud_layout") built from the
## same widgets: hearts, lives, shield stamina, shard meter, fragments + challenges.
## Overlays: title card, hints, interaction prompt, course timer, compass, hurt vignette, fades.

var meter: ShardMeter
var hearts: HeartsBar
var lives_bar: LivesBar
var stamina_bar: ProgressBar
var challenges: ChallengeList
var clock: Label
var hint_label: Label
var prompt_label: Label
var timer_label: Label
var title: Label
var subtitle: Label
var fade: ColorRect
var hurt_fx: ColorRect
var compass: Control

var _root: Control
var _panels: Control
var _layout := -1
var _hint_tween: Tween
var _shards := 0
var _shards_total := 3
var _health := 3
var _lives := 3
var _unlimited := true
var _stamina := 1.0
var _stamina_active := false


func _ready() -> void:
	add_to_group("hud")
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)

	hurt_fx = ColorRect.new()
	hurt_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float amount = 0.0;\nvoid fragment() { float d = distance(UV, vec2(0.5)); COLOR = vec4(0.6, 0.05, 0.1, smoothstep(0.35, 0.8, d) * amount); }"
	sm.shader = sh
	hurt_fx.material = sm
	_root.add_child(hurt_fx)

	compass = Compass.new()
	compass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(compass)

	_panels = Control.new()
	_panels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panels)

	timer_label = _label(40)
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	timer_label.visible = false
	_root.add_child(timer_label)
	prompt_label = _label(22)
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	prompt_label.label_settings.font_color = UITheme.GOLD
	_root.add_child(prompt_label)
	hint_label = _label(24)
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hint_label.modulate.a = 0.0
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(hint_label)

	title = UITheme.title_label("", 92)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.offset_bottom = -90
	title.modulate.a = 0.0
	_root.add_child(title)
	subtitle = _label(22)
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.offset_top = 30
	subtitle.modulate.a = 0.0
	_root.add_child(subtitle)

	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(1, 0.97, 0.92, 0.0)
	_root.add_child(fade)

	_build_layout()
	Settings.changed.connect(_build_layout)


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := LabelSettings.new()
	s.font = UITheme.ui_font(700)
	s.font_size = font_size
	s.font_color = UITheme.CREAM
	s.outline_size = max(2, font_size / 8)
	s.outline_color = Color(0.1, 0.06, 0.04, 0.4)
	s.shadow_size = 8
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_offset = Vector2(0, 2)
	l.label_settings = s
	return l


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.08, 0.38)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	return p


func _widgets() -> void:
	meter = ShardMeter.new()
	meter.total = _shards_total
	meter.count = _shards
	hearts = HeartsBar.new()
	hearts.current = _health
	lives_bar = LivesBar.new()
	lives_bar.lives = _lives
	lives_bar.unlimited = _unlimited
	lives_bar.maximum = Difficulty.lives()
	stamina_bar = ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(96, 6)
	stamina_bar.max_value = 1.0
	stamina_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.15)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.55, 0.85, 1.0, 0.9)
	fg.set_corner_radius_all(3)
	stamina_bar.add_theme_stylebox_override("background", bg)
	stamina_bar.add_theme_stylebox_override("fill", fg)
	stamina_bar.value = _stamina
	stamina_bar.modulate.a = 1.0 if (_stamina_active or _stamina < 0.999) else 0.0
	clock = Label.new()
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cs := LabelSettings.new()
	cs.font = UITheme.ui_font(700)
	cs.font_size = 20
	cs.font_color = Color(1, 0.96, 0.9, 0.9)
	cs.font_color = Color(1, 0.97, 0.92, 1.0)
	cs.outline_size = 6
	cs.outline_color = Color(0.08, 0.05, 0.04, 0.7)
	cs.shadow_size = 6
	cs.shadow_color = Color(0, 0, 0, 0.3)
	clock.label_settings = cs
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	challenges = ChallengeList.new()
	challenges.session = get_tree().get_first_node_in_group("session") as Session


func _status_box(horizontal := false) -> BoxContainer:
	var b: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
	b.add_theme_constant_override("separation", 14 if horizontal else 6)
	b.add_child(hearts)
	b.add_child(lives_bar)
	var s := VBoxContainer.new()
	s.alignment = BoxContainer.ALIGNMENT_CENTER
	s.add_child(stamina_bar)
	b.add_child(s)
	return b


func _build_layout() -> void:
	var layout := int(Settings.get_v("hud_layout"))
	if layout == _layout and meter != null:
		return
	_layout = layout
	for c in _panels.get_children():
		c.queue_free()
	_widgets()
	match layout:
		1:  # Side: one column on the left
			var p := _panel()
			p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
			p.position = Vector2(20, 0)
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 10)
			v.add_child(meter)
			v.add_child(clock)
			v.add_child(_status_box())
			var sep := HSeparator.new()
			sep.modulate.a = 0.4
			v.add_child(sep)
			v.add_child(challenges)
			p.add_child(v)
			_panels.add_child(p)
			p.resized.connect(func(): p.position.y = (_panels.size.y - p.size.y) / 2.0)
			_place_text(true)
		2:  # Bottom bar
			var left := _panel()
			left.add_child(_status_box(true))
			var mid := _panel()
			var mh := HBoxContainer.new()
			mh.add_theme_constant_override("separation", 10)
			mh.add_child(meter)
			clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			clock.custom_minimum_size = Vector2(64, 44)
			mh.add_child(clock)
			mid.add_child(mh)
			var right := _panel()
			challenges.align_right = true
			right.add_child(challenges)
			for pnl in [left, mid, right]:
				_panels.add_child(pnl)
			var place := func():
				var h := _panels.size
				left.position = Vector2(20, h.y - left.size.y - 20)
				mid.position = Vector2((h.x - mid.size.x) / 2.0, h.y - mid.size.y - 20)
				right.position = Vector2(h.x - right.size.x - 20, h.y - right.size.y - 20)
			for pnl in [left, mid, right]:
				pnl.resized.connect(place)
			_panels.resized.connect(place)
			place.call_deferred()
			_place_text(false, true)
		_:  # Top
			var left := _panel()
			left.add_child(_status_box())
			left.position = Vector2(20, 20)
			var mid := Control.new()
			mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mid.add_child(meter)
			mid.add_child(clock)
			var right := _panel()
			challenges.align_right = true
			right.add_child(challenges)
			for pnl in [left, mid, right]:
				_panels.add_child(pnl)
			var place := func():
				var w := _panels.size.x
				meter.position = Vector2((w - meter.custom_minimum_size.x) / 2.0, 14)
				clock.size = Vector2(120, 26)
				clock.position = Vector2((w - 120.0) / 2.0, 56)
				right.position = Vector2(w - right.size.x - 20, 20)
			right.resized.connect(place)
			_panels.resized.connect(place)
			place.call_deferred()
			_place_text(false)


func _place_text(side: bool, bottom := false) -> void:
	timer_label.offset_top = (96 if _layout == 0 else 64) if not bottom else 30
	hint_label.offset_left = 380 if side else 200
	hint_label.offset_right = -200
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP if bottom else VERTICAL_ALIGNMENT_BOTTOM
	hint_label.offset_top = 110 if bottom else 0
	hint_label.offset_bottom = 0 if bottom else -64
	prompt_label.offset_bottom = -150 if bottom else -130


func _process(_dt: float) -> void:
	var s := get_tree().get_first_node_in_group("session") as Session
	if clock and s:
		var t := s.elapsed
		clock.text = "%d:%02d" % [int(t) / 60, int(t) % 60]


# ------------------------------------------------------------ API used by the game

func setup(total_shards: int) -> void:
	_shards_total = total_shards
	meter.total = total_shards


func hint(text: String, duration := 5.0) -> void:
	if _hint_tween:
		_hint_tween.kill()
	hint_label.text = text
	_hint_tween = create_tween()
	_hint_tween.tween_property(hint_label, "modulate:a", 1.0, 0.5)
	_hint_tween.tween_interval(duration)
	_hint_tween.tween_property(hint_label, "modulate:a", 0.0, 1.0)


func set_prompt(text: String) -> void:
	prompt_label.text = text


func set_timer(t: float) -> void:
	timer_label.visible = true
	timer_label.text = "%.1f" % max(t, 0.0)
	timer_label.label_settings.font_color = UITheme.CREAM if t > 5.0 else Color(1, 0.5, 0.4)


func clear_timer() -> void:
	timer_label.visible = false


func set_health(h: int) -> void:
	if h < _health:
		hearts.flash = 1.0
		var m := hurt_fx.material as ShaderMaterial
		m.set_shader_parameter("amount", 1.0)
		create_tween().tween_method(func(v): m.set_shader_parameter("amount", v), 1.0, 0.0, 0.8)
	_health = h
	hearts.current = max(h, 0)


## n < 0 means unlimited (Practice mode).
func set_lives(n: int) -> void:
	_unlimited = n < 0
	_lives = max(n, 0)
	lives_bar.unlimited = _unlimited
	lives_bar.maximum = maxi(Difficulty.lives(), _lives)
	lives_bar.lives = _lives


func set_fragments(_n: int, _total: int) -> void:
	pass  # the challenge list reads fragment progress live


func set_stamina(v: float, active: bool) -> void:
	_stamina = v
	_stamina_active = active
	stamina_bar.value = v
	stamina_bar.modulate.a = 1.0 if (active or v < 0.999) else 0.0


func show_title(main: String, sub: String, hold := 3.0) -> void:
	title.text = main
	subtitle.text = sub
	var t := create_tween().set_parallel(true)
	t.tween_property(title, "modulate:a", 1.0, 1.6)
	t.tween_property(subtitle, "modulate:a", 0.85, 1.6).set_delay(0.6)
	t.chain().tween_interval(hold)
	t.chain().tween_property(title, "modulate:a", 0.0, 1.6)
	t.parallel().tween_property(subtitle, "modulate:a", 0.0, 1.6)


func set_shards(n: int) -> void:
	_shards = n
	meter.count = n
	meter.pulse = 1.0


func flash(strength := 0.85, color := Color(1, 0.97, 0.92)) -> void:
	fade.color = Color(color.r, color.g, color.b, strength)
	create_tween().tween_property(fade, "color:a", 0.0, 1.2)
