class_name PhotoMode
extends CanvasLayer
## Free-fly camera with the world frozen and the HUD hidden. Time of day is adjustable.

signal closed

var session: Session
var cam: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _help: Label
var _hour_label: Label
var _saved_hour := 0.0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var src := get_viewport().get_camera_3d()
	cam = Camera3D.new()
	cam.far = 3000.0
	cam.fov = src.fov if src else 70.0
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	session.add_child(cam)
	if src:
		cam.global_transform = src.global_transform
	_saved_hour = session.cycle.hour
	_yaw = cam.rotation.y
	_pitch = cam.rotation.x
	cam.make_current()
	session.hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)
	_help = Label.new()
	_help.position = Vector2(24, 20)
	_help.add_theme_font_size_override("font_size", 16)
	_help.modulate = Color(1, 1, 1, 0.85)
	_help.text = "PHOTO MODE\nMove: %s/%s/%s/%s · Up/Down: %s / %s · Mouse: look\nScroll: zoom · [ and ]: time of day · H: hide this · %s: exit" % [
		Settings.key_label("move_forward"), Settings.key_label("move_left"), Settings.key_label("move_back"),
		Settings.key_label("move_right"), Settings.key_label("jump"), Settings.key_label("sprint"), Settings.key_label("pause")]
	root.add_child(_help)
	_hour_label = Label.new()
	_hour_label.position = Vector2(24, 92)
	_hour_label.add_theme_font_size_override("font_size", 16)
	root.add_child(_hour_label)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * 0.0025
		_pitch = clamp(_pitch - event.relative.y * 0.0025, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.fov = clamp(cam.fov - 3.0, 15.0, 110.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.fov = clamp(cam.fov + 3.0, 15.0, 110.0)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_H:
			_help.visible = not _help.visible
			_hour_label.visible = _help.visible
		elif event.is_action("pause") or event.is_action("photo"):
			get_viewport().set_input_as_handled()
			_close()


func _process(dt: float) -> void:
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var up := (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_action_pressed("sprint") else 0.0)
	cam.rotation = Vector3(_pitch, _yaw, 0)
	var v := cam.global_basis * Vector3(move.x, 0, move.y) + Vector3.UP * up
	cam.global_position += v * 12.0 * dt
	var c := session.cycle
	var dh := (1.0 if Input.is_key_pressed(KEY_BRACKETRIGHT) else 0.0) - (1.0 if Input.is_key_pressed(KEY_BRACKETLEFT) else 0.0)
	if dh != 0.0:
		c.hour = fposmod(c.hour + dh * 3.0 * dt, 24.0)
		c._apply()
	_hour_label.text = "Time  %02d:%02d" % [int(c.hour), int(fmod(c.hour, 1.0) * 60.0)]


func _close() -> void:
	# Photo-mode time changes are only for the picture; the game resumes at its own time.
	session.cycle.hour = _saved_hour
	session.cycle._apply()
	session.hud.visible = true
	session.player.camera.make_current()
	cam.queue_free()
	closed.emit()
	queue_free()
