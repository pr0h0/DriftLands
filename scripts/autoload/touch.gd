extends CanvasLayer
## On-screen controls for phones and tablets: a floating stick on the left, drag anywhere else to
## look, and buttons for jump/glide, run/dive, shield, use, return and pause. Settings
## "touch_controls" picks Auto (on for phones, or after the first touch), On or Off. While active
## the UI is scaled for small screens and a "turn sideways" card covers portrait mode.

signal toggled(on: bool)

const BASE_SIZE := Vector2i(1280, 720)  # logical UI size while active (width expands)
const STICK_R := 85.0
const STICK_DEADZONE := 0.25  # of the stick radius: thumb wobble near the center does nothing
const LOOK_SENS := 0.0025  # radians per logical pixel at 1.0× touch sensitivity

var active := false

var _draw_root: Control
var _rotate_card: Control
var _buttons := {}  # name -> {action, pos, r, label, hold}
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _look_id := -1
var _pressed := {}  # touch index -> button name
var _seen_touch := false
var _laid_out_for := Vector2.ZERO


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_root = Control.new()
	_draw_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_root.draw.connect(_draw_controls)
	add_child(_draw_root)
	_build_rotate_card()
	Settings.changed.connect(_refresh)
	get_viewport().size_changed.connect(_layout)
	_refresh()


static func is_mobile() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")


func _refresh() -> void:
	var mode := int(Settings.get_v("touch_controls"))
	var want := mode == 1 or (mode == 0 and (is_mobile() or _seen_touch))
	if want == active:
		return
	active = want
	var win := get_window()
	if active:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		win.content_scale_size = BASE_SIZE
	else:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		_release_all()
	_layout()
	toggled.emit(active)


## Short on-screen name of the button for an action (for prompts and hints).
func button_name(action: String) -> String:
	match action:
		"jump":
			return "Jump"
		"sprint":
			return "Run"
		"interact":
			return "Use"
		"block":
			return "Shield"
		"respawn":
			return "Return"
		"pause":
			return "Pause"
	return action.capitalize()


## iPhone/iPad browsers can't go fullscreen; added to the Home Screen the game opens without
## browser bars. Returns the tip to show, or "" when it doesn't apply (or already installed).
func home_screen_tip() -> String:
	var ios := OS.has_feature("web_ios") or OS.get_cmdline_user_args().has("--iostip")
	if not ios:
		return ""
	if OS.has_feature("web") and JavaScriptBridge.eval("!!(navigator.standalone || matchMedia('(display-mode: fullscreen), (display-mode: standalone)').matches)", true):
		return ""
	return "Tip: tap Share, then Add to Home Screen, to play fullscreen"


# ------------------------------------------------------------ layout

func _layout() -> void:
	var s := _draw_root.get_viewport_rect().size
	_laid_out_for = s
	_buttons = {
		"jump": {"action": "jump", "pos": Vector2(s.x - 125, s.y - 135), "r": 62.0, "label": "Jump"},
		"sprint": {"action": "sprint", "pos": Vector2(s.x - 270, s.y - 90), "r": 46.0, "label": "Run"},
		"block": {"action": "block", "pos": Vector2(s.x - 255, s.y - 225), "r": 42.0, "label": "Shield"},
		"interact": {"action": "interact", "pos": Vector2(s.x - 120, s.y - 290), "r": 46.0, "label": "Use"},
		"pause": {"action": "pause", "pos": Vector2(46, 175), "r": 27.0, "label": ""},
		"respawn": {"action": "respawn", "pos": Vector2(46, 240), "r": 27.0, "label": ""},
	}
	_rotate_card.visible = active and s.y > s.x
	_draw_root.queue_redraw()


func _build_rotate_card() -> void:
	_rotate_card = ColorRect.new()
	(_rotate_card as ColorRect).color = Color(0.06, 0.05, 0.09, 0.96)
	_rotate_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rotate_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_rotate_card.visible = false
	var l := Label.new()
	l.text = "Turn your device sideways\nDriftlands plays in landscape"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ls := LabelSettings.new()
	ls.font = UITheme.ui_font(700)
	ls.font_size = 30
	ls.font_color = UITheme.CREAM
	l.label_settings = ls
	_rotate_card.add_child(l)
	add_child(_rotate_card)


## The player while gameplay controls make sense (not paused, not in a menu or cutscene).
func _player() -> Player:
	if not active or get_tree().paused:
		return null
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or not p.input_enabled:
		return null
	return p


func _process(_dt: float) -> void:
	if _draw_root.get_viewport_rect().size != _laid_out_for:
		_layout()  # the scaled UI size only settles a frame after the scale mode changes
	var show: bool = _player() != null
	if not show and (_stick_id != -1 or _look_id != -1 or not _pressed.is_empty()):
		_release_all()
	_draw_root.visible = show
	if show:
		_draw_root.queue_redraw()


# ------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not _seen_touch:
		_seen_touch = true
		_first_touch()
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	var p := _player()
	if p == null or _rotate_card.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	else:
		_touch_drag(event.index, event.position, event.relative, p)


func _touch_down(id: int, pos: Vector2) -> void:
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		if _button_shown(name) and pos.distance_to(b.pos) <= float(b.r) * 1.25:
			_pressed[id] = name
			_send(b.action, true)
			return
	var s := _draw_root.get_viewport_rect().size
	if _stick_id == -1 and pos.x < s.x * 0.42 and pos.y > s.y * 0.3:
		_stick_id = id
		_stick_origin = pos
		_stick_vec = Vector2.ZERO
	elif _look_id == -1:
		_look_id = id


func _touch_up(id: int) -> void:
	if _pressed.has(id):
		_send(_buttons[_pressed[id]].action, false)
		_pressed.erase(id)
	elif id == _stick_id:
		_stick_id = -1
		_set_stick(Vector2.ZERO)
	elif id == _look_id:
		_look_id = -1


func _touch_drag(id: int, pos: Vector2, rel: Vector2, p: Player) -> void:
	if id == _stick_id:
		var d := pos - _stick_origin
		if d.length() > STICK_R:  # the stick follows a thumb that slides past its rim
			_stick_origin = pos - d.normalized() * STICK_R
			d = pos - _stick_origin
		_set_stick(d / STICK_R)
	elif id == _look_id:
		p.look_by(rel, LOOK_SENS * float(Settings.get_v("touch_sens")))


## v is the thumb offset in stick radii. A dead zone and a curve keep small pushes gentle:
## a light push walks slowly, the outer ring runs at full speed.
func _set_stick(v: Vector2) -> void:
	_stick_vec = v
	var out := Vector2.ZERO
	var l := minf(v.length(), 1.0)
	if l > STICK_DEADZONE:
		var t := (l - STICK_DEADZONE) / (1.0 - STICK_DEADZONE)
		# Input.get_vector() applies the actions' own 0.2 dead zone again, so start past it.
		out = v.normalized() * (0.2 + 0.8 * pow(t, 1.5))
	for pair in [["move_right", out.x], ["move_left", -out.x], ["move_back", out.y], ["move_forward", -out.y]]:
		if pair[1] > 0.0:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


## Feeds a button as an action event, so both polling and _unhandled_input code see it.
func _send(action: String, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(e)


func _release_all() -> void:
	for id in _pressed:
		_send(_buttons[_pressed[id]].action, false)
	_pressed.clear()
	_stick_id = -1
	_look_id = -1
	_set_stick(Vector2.ZERO)


## On a phone, the first tap goes fullscreen and asks the browser to hold landscape.
func _first_touch() -> void:
	if int(Settings.get_v("touch_controls")) == 0 and not active:
		_refresh()
	if not active or not OS.has_feature("web") or not is_mobile():
		return
	if not Settings.is_fullscreen():
		Settings.set_v("fullscreen", true)
	await get_tree().create_timer(0.4).timeout
	JavaScriptBridge.eval("try { screen.orientation.lock('landscape').catch(function(){}); } catch (e) {}")


# ------------------------------------------------------------ drawing

func _button_shown(name: String) -> bool:
	if name == "interact":
		var p := get_tree().get_first_node_in_group("player") as Player
		return p != null and (p.carrying != null or p.interact_target != null)
	return true


func _draw_controls() -> void:
	var ci := _draw_root
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null:
		return
	var font := UITheme.ui_font(700)
	var s := ci.get_viewport_rect().size
	# Move stick: resting hint when idle, live ring + knob while held.
	var origin := _stick_origin if _stick_id != -1 else Vector2(170, s.y - 170)
	ci.draw_circle(origin, STICK_R, Color(0, 0, 0, 0.18 if _stick_id != -1 else 0.1))
	ci.draw_arc(origin, STICK_R, 0, TAU, 48, Color(1, 0.97, 0.9, 0.5 if _stick_id != -1 else 0.25), 3.0, true)
	ci.draw_circle(origin + _stick_vec.limit_length(1.0) * STICK_R, 30.0, Color(1, 0.97, 0.9, 0.55 if _stick_id != -1 else 0.25))
	var held := _pressed.values()
	for name in _buttons:
		if not _button_shown(name):
			continue
		var b: Dictionary = _buttons[name]
		var down: bool = name in held
		var r: float = b.r
		var tint := Color(1, 0.97, 0.9)
		if name == "interact":
			tint = UITheme.GOLD
		ci.draw_circle(b.pos, r, Color(0, 0, 0, 0.32 if down else 0.2))
		ci.draw_arc(b.pos, r, 0, TAU, 48, Color(tint, 0.85 if down else 0.5), 3.0, true)
		match name:
			"pause":
				for dx in [-7.0, 4.0]:
					ci.draw_rect(Rect2(b.pos + Vector2(dx, -10), Vector2(5, 20)), Color(tint, 0.8))
			"respawn":
				ci.draw_arc(b.pos, 11.0, -PI * 0.15, PI * 1.45, 24, Color(tint, 0.8), 3.0, true)
				var tip: Vector2 = b.pos + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * 11.0
				ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-6, -4), tip + Vector2(5, -6), tip + Vector2(2, 6)]), Color(tint, 0.8))
			_:
				var text: String = b.label
				if name == "jump" and not p.is_on_floor():
					text = "Fold" if p.gliding else "Glide"
				elif name == "sprint" and not p.is_on_floor():
					text = "Dive"
				elif name == "interact" and p.carrying:
					text = "Drop"
				var fs := 22 if r > 50.0 else 18
				var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				ci.draw_string(font, b.pos + Vector2(-w / 2.0, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(tint, 0.9 if down else 0.75))
