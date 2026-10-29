class_name EchoCrystal
extends Area3D
## Touch to summon a path of echo stones that light up one after another, linger, then fade
## in the same order. Move with the light.

var stones: Array = []  # PhasePlatform in "manual" mode
var linger := 9.0
var step := 0.4
var _cool := 0.0
var _mat: StandardMaterial3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.6
	cs.shape = s
	cs.position.y = 1.4
	add_child(cs)
	add_child(Assets.spawn("beam_pedestal", true, 2))
	var crystal := Assets.spawn("shard", false)
	crystal.position.y = 1.7
	add_child(crystal)
	_mat = ElUtil.unique_mat(crystal, "crystal") as StandardMaterial3D
	_mat.emission = Color(0.6, 1.0, 0.75)
	body_entered.connect(_on_body)


func _process(dt: float) -> void:
	_cool -= dt
	_mat.emission_energy_multiplier = 2.5 if _cool <= 0.0 else 0.6


func _on_body(b: Node3D) -> void:
	if not b is Player or _cool > 0.0:
		return
	_cool = linger + stones.size() * step + 1.0
	Sound.play_at("echo", global_position)
	ElUtil.hint(self, "echo", "Echo stones appear in sequence and fade the same way. Go!")
	for i in stones.size():
		get_tree().create_timer(i * step).timeout.connect(func(): stones[i].present = true; Sound.play_at("gate", stones[i].global_position, -10.0, 1.4 + i * 0.05))
		get_tree().create_timer(linger + i * step).timeout.connect(func(): stones[i].present = false)
