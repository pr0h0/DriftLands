class_name PauseMenu
extends CanvasLayer
## In-game pause overlay. Runs while the tree is paused.

signal resumed
signal restart_checkpoint
signal restart_level
signal quit_to_menu
signal photo

var _root: Control
var _main: VBoxContainer
var _settings: SettingsMenu


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UITheme.get_theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 10)
	panel.add_child(_main)
	_main.add_child(UITheme.title_label("Paused", 54))
	_main.add_child(UITheme.button("Resume", func(): resumed.emit()))
	_main.add_child(UITheme.button("Return to last checkpoint", func(): restart_checkpoint.emit()))
	_main.add_child(UITheme.button("Restart level", func(): restart_level.emit()))
	_main.add_child(UITheme.button("Photo mode  (F2)", func(): photo.emit()))
	_main.add_child(UITheme.button("Settings", _open_settings))
	_main.add_child(UITheme.fullscreen_button())
	_main.add_child(UITheme.button("Main menu", func(): quit_to_menu.emit()))
	_settings = SettingsMenu.new()
	_settings.visible = false
	_settings.closed.connect(_close_settings)
	center.add_child(_settings)
	visible = false


func open() -> void:
	visible = true
	_close_settings()
	(_main.get_child(1) as Button).grab_focus()


func close() -> void:
	visible = false


func _open_settings() -> void:
	_main.get_parent().visible = false
	_settings.visible = true


func _close_settings() -> void:
	_settings.visible = false
	_main.get_parent().visible = true


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _settings.visible:
			_close_settings()
		else:
			resumed.emit()
