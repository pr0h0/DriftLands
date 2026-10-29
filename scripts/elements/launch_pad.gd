class_name LaunchPad
extends Area3D
## Step on it to be launched straight up. Open your glider at the top.

var power := 21.0
var _cool := 0.0
var _glow_mat: Material
var _light: OmniLight3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 1.4, 2.6)
	cs.shape = box
	cs.position.y = 0.8
	add_child(cs)
	var model := Assets.spawn("launch_pad", true, 2)
	add_child(model)
	_glow_mat = ElUtil.unique_mat(model, "rune")
	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.88, 1.0)
	_light.position.y = 0.8
	_light.omni_range = 5.0
	add_child(_light)
	var p := FX.streaks(0.9, 6.0)
	p.amount = 20
	add_child(p)
	body_entered.connect(_on_body)


func _process(dt: float) -> void:
	_cool -= dt
	var k: float = 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.3 + max(_cool, 0.0) * 4.0
	(_glow_mat as StandardMaterial3D).emission_energy_multiplier = 1.5 * k
	_light.light_energy = 0.8 * k


func _on_body(b: Node3D) -> void:
	if not b is Player or _cool > 0.0:
		return
	_cool = 0.8
	b.launch(power)
	Sound.play("launch", -2.0)
	ElUtil.hint(self, "pad", "Launch pads throw you skyward. Open your glider at the top.")
