class_name UITheme
## Shared look for menus: Nunito UI text, Cormorant titles, soft translucent panels.

const CREAM := Color(1.0, 0.96, 0.9)
const GOLD := Color(1.0, 0.82, 0.5)

static var _theme: Theme
static var _title_font: FontVariation


static func title_font() -> FontVariation:
	if _title_font == null:
		_title_font = FontVariation.new()
		_title_font.base_font = load("res://assets/fonts/CormorantGaramond.ttf")
		_title_font.variation_opentype = {"wght": 600}
		_title_font.spacing_glyph = 2
	return _title_font


static func ui_font(weight := 600) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/Nunito.ttf")
	f.variation_opentype = {"wght": weight}
	return f


static func _box(bg: Color, radius := 12, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = ui_font()
	t.default_font_size = 20
	t.set_color("font_color", "Label", CREAM)
	for cls in ["Button", "OptionButton", "CheckBox"]:
		t.set_color("font_color", cls, CREAM)
		t.set_color("font_hover_color", cls, GOLD)
		t.set_color("font_focus_color", cls, GOLD)
		t.set_color("font_pressed_color", cls, Color.WHITE)
		t.set_color("font_disabled_color", cls, Color(1, 1, 1, 0.3))
	t.set_stylebox("normal", "Button", _box(Color(1, 1, 1, 0.05)))
	var hover := _box(Color(1, 0.85, 0.6, 0.2), 12, Color(1, 0.85, 0.6, 0.85), 0)
	hover.border_width_left = 4
	hover.content_margin_left = 26
	t.set_stylebox("hover", "Button", hover)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(1, 0.85, 0.6, 0.34)
	t.set_stylebox("pressed", "Button", pressed)
	var focus := _box(Color(0, 0, 0, 0), 12, Color(1, 0.85, 0.6, 0.85), 0)
	focus.border_width_left = 4
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", _box(Color(1, 1, 1, 0.02)))
	t.set_stylebox("normal", "OptionButton", _box(Color(1, 1, 1, 0.07)))
	t.set_stylebox("hover", "OptionButton", _box(Color(1, 0.85, 0.6, 0.16)))
	t.set_stylebox("pressed", "OptionButton", _box(Color(1, 0.85, 0.6, 0.22)))
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.06, 0.05, 0.08, 0.78), 18))
	t.set_stylebox("panel", "PopupMenu", _box(Color(0.08, 0.07, 0.1, 0.96), 10))
	t.set_stylebox("panel", "TabContainer", _box(Color(0, 0, 0, 0), 0))
	t.set_stylebox("tab_selected", "TabContainer", _box(Color(1, 0.85, 0.6, 0.18), 10))
	t.set_stylebox("tab_unselected", "TabContainer", _box(Color(1, 1, 1, 0.03), 10))
	t.set_stylebox("tab_hovered", "TabContainer", _box(Color(1, 1, 1, 0.1), 10))
	t.set_color("font_selected_color", "TabContainer", GOLD)
	t.set_color("font_unselected_color", "TabContainer", CREAM)
	var slider := StyleBoxFlat.new()
	slider.bg_color = Color(1, 1, 1, 0.15)
	slider.set_corner_radius_all(3)
	slider.content_margin_top = 3
	slider.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", slider)
	var fill := slider.duplicate() as StyleBoxFlat
	fill.bg_color = Color(1, 0.82, 0.5, 0.8)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	_theme = t
	return t


static func title_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	var s := LabelSettings.new()
	s.font = title_font()
	s.font_size = size
	s.font_color = CREAM
	s.shadow_size = 10
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_offset = Vector2(0, 3)
	l.label_settings = s
	return l


## A button that toggles fullscreen and keeps its label in sync.
static func fullscreen_button(min_w := 300) -> Button:
	var b := button("", func(): Settings.toggle_fullscreen(), min_w)
	var refresh := func(): b.text = "Exit fullscreen" if Settings.is_fullscreen() else "Fullscreen  (F11)"
	refresh.call()
	b.pressed.connect(func(): b.get_tree().create_timer(0.3).timeout.connect(refresh))
	b.visibility_changed.connect(refresh)
	Settings.changed.connect(func(): if is_instance_valid(b): refresh.call())
	return b


static func button(text: String, cb: Callable, min_w := 300) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(min_w, 46)
	b.pressed.connect(func(): Sound.play("ui_click", -4.0); cb.call())
	b.mouse_entered.connect(func(): Sound.play("ui_hover", -10.0))
	return b
