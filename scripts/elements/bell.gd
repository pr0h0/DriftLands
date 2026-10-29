class_name Bell
extends Node3D
## Resonance bell: ringing sends a wave across the sky. Stays "on" for `window` seconds,
## so several bells rung together can open seals or hold up light bridges.

signal changed

var window := 12.0
var _on_t := 0.0
var _bell: Node3D
var _wave: MeshInstance3D
var _wave_mat: StandardMaterial3D
var _wave_tween: Tween


func is_on() -> bool:
	return _on_t > 0.0


func _ready() -> void:
	add_to_group("interactable")
	var model := Assets.spawn("bell", true, 2)
	add_child(model)
	_bell = Assets.find(model, "Bell_deco") as Node3D
	_wave = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.95
	t.outer_radius = 1.0
	t.rings = 64
	t.ring_segments = 4
	_wave.mesh = t
	_wave_mat = ElUtil.glow_mat(Color(1.0, 0.85, 0.5), 1.5)
	_wave.material_override = _wave_mat
	_wave.position.y = 1.6
	_wave.visible = false
	_wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wave)


func interact_prompt() -> String:
	return "Ring the bell" if not is_on() else "Ringing… (%ds)" % ceil(_on_t)


func interact() -> void:
	var was := is_on()
	_on_t = window
	Sound.play_at("bell_ring", global_position)
	_bell.rotation.x = 0.35
	create_tween().tween_property(_bell, "rotation:x", 0.0, 1.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_wave.visible = true
	_wave.scale = Vector3.ONE
	_wave_mat.albedo_color = Color(1.0, 0.85, 0.5) * 1.5
	if _wave_tween:
		_wave_tween.kill()
	_wave_tween = create_tween().set_parallel(true)
	_wave_tween.tween_property(_wave, "scale", Vector3.ONE * 45.0, 2.5).set_ease(Tween.EASE_OUT)
	_wave_tween.tween_property(_wave_mat, "albedo_color", Color(0, 0, 0, 0), 2.5)
	_wave_tween.chain().tween_callback(func(): _wave.visible = false)
	ElUtil.hint(self, "bells", "Bells resonate for a while. Ring them all before the first one fades.")
	if not was:
		changed.emit()


func _process(dt: float) -> void:
	if _on_t > 0.0:
		_on_t -= dt
		if _on_t <= 0.0:
			changed.emit()
