extends Node
## Screen router: title menu <-> game sessions, with a loading veil between them.
##
## Command-line (after `--`): --level=N [--resume] jumps straight into a level;
## --shot / --probe options are handled by Session (see session.gd).

var current: Node
var veil: CanvasLayer
var _veil_rect: ColorRect
var _veil_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_veil()
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var kv := String(arg).trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("fakeprogress"):
		# Debug: pretend N levels are done with every star and fragment (in memory only).
		Progress.readonly = true
		for i in int(args["fakeprogress"]):
			Progress.data["levels"][str(i + 1)] = {"done": true, "best": 200.0, "challenges": {"flawless": true, "time": true, "fragments": true}, "fragments": [0, 1, 2, 3, 4]}
		Progress.data["unlocked"] = int(args["fakeprogress"]) + 1
	if args.has("adaptive"):  # debug: adaptive resolution as on phones
		Settings.values["adaptive_res"] = true
	if args.has("touch") or args.has("touchtest"):  # debug: force the on-screen controls
		Settings.values["touch_controls"] = 1
		Touch._refresh()
	if args.has("uitest"):
		await _ui_test(args)
		return
	if args.has("level"):
		start_level(int(args["level"]), args.has("resume"), args)
	else:
		await show_title()
		if args.has("page"):  # debug: wardrobe, journal, modes, chapters
			await get_tree().create_timer(1.5).timeout
			current.call("_show_" + String(args["page"]))
		if args.has("shot"):
			for i in int(args.get("frames", "120")):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(args["shot"])
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		Settings.toggle_fullscreen()


## Debug: render the complete screen or the chapters list with sample progress (nothing is saved).
func _ui_test(args: Dictionary) -> void:
	Progress.data = {"unlocked": 5, "checkpoint": {}, "levels": {
		"1": {"done": true, "best": 201.0, "challenges": {"flawless": true, "time": true, "fragments": true}, "fragments": [0, 1, 2, 3, 4]},
		"2": {"done": true, "best": 412.0, "challenges": {"flawless": false, "time": true, "fragments": false}, "fragments": [0, 2]},
		"3": {"done": true, "best": 380.0, "challenges": {"flawless": true, "time": false, "fragments": false}, "fragments": [1]},
		"4": {"done": true, "best": 455.0, "challenges": {}, "fragments": []}}}
	if args["uitest"] == "complete":
		var bg := TitleScreen.new()
		add_child(bg)
		await get_tree().create_timer(1.0).timeout
		bg.get_child(bg.get_child_count() - 1).visible = false
		add_child(CompleteScreen.new().setup(2, 245.0, true, {"flawless": true, "time": true, "fragments": false}, 360.0))
	else:
		var t := TitleScreen.new()
		add_child(t)
		await get_tree().create_timer(1.0).timeout
		t._show_chapters()
	for i in 200:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args["shot"])
	get_tree().quit()


func _build_veil() -> void:
	veil = CanvasLayer.new()
	veil.layer = 50
	veil.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(veil)
	_veil_rect = ColorRect.new()
	_veil_rect.color = Color(0.05, 0.04, 0.07, 0.0)
	_veil_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.add_child(_veil_rect)
	_veil_label = UITheme.title_label("", 52)
	_veil_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_veil_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_veil_label.modulate.a = 0.0
	veil.add_child(_veil_label)


func _veil(on: bool, text := "") -> void:
	_veil_label.text = text
	var t := create_tween().set_parallel(true)
	t.tween_property(_veil_rect, "color:a", 1.0 if on else 0.0, 0.5 if on else 1.2)
	t.tween_property(_veil_label, "modulate:a", 1.0 if on else 0.0, 0.5 if on else 0.8)
	await t.finished


func _swap(node: Node) -> void:
	get_tree().paused = false
	if current:
		current.queue_free()
		await get_tree().process_frame
	current = node
	add_child(node)


func show_title() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _veil(true)
	var t := TitleScreen.new()
	t.start_level.connect(func(id, resume): start_level(id, resume))
	await _swap(t)
	await get_tree().create_timer(0.3).timeout
	_veil(false)


func start_level(id: int, resume := false, args := {}) -> void:
	await _veil(true, Levels.title_of(id))
	var s := Session.new()
	s.level_id = id
	s.resume = resume
	s.args = args
	s.to_menu.connect(show_title)
	s.to_level.connect(func(nid, r): start_level(nid, r))
	await _swap(s)
	await s.ready_to_play
	_veil(false)
