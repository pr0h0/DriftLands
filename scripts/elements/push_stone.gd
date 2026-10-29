class_name PushStone
extends RigidBody3D
## A heavy rune block the player can shove around. Returns home if it falls off the world.

const PUSH_SPEED := 2.4

var home: Vector3
var _push := Vector3.ZERO
var _push_t := 0.0


## Called by the player every frame they shove into the stone.
func push(dir: Vector3) -> void:
	_push = Vector3(dir.x, 0, dir.z).normalized()
	_push_t = 0.12
	ElUtil.hint(self, "push", "Walk into a stone to push it. Rest it on a plate to keep the plate down.")


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8
	mass = 30.0
	linear_damp = 2.0
	angular_damp = 6.0
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	axis_lock_angular_y = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.2, 1.2)
	cs.shape = box
	cs.position.y = 0.6
	add_child(cs)
	add_child(Assets.spawn("push_stone", false))
	home = global_position


func _physics_process(dt: float) -> void:
	_push_t -= dt
	if _push_t > 0.0:
		linear_velocity = Vector3(_push.x * PUSH_SPEED, linear_velocity.y, _push.z * PUSH_SPEED)
	elif linear_velocity.y > -0.5:
		linear_velocity = Vector3(0, linear_velocity.y, 0)
	# Pushed off the edge (or carried far away): glide back home instead of falling forever.
	var away := Vector2(global_position.x - home.x, global_position.z - home.z).length()
	if global_position.y < home.y - 3.0 or away > 22.0:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		global_position = home + Vector3.UP * 1.0
		Sound.play_at("checkpoint", home, -8.0)
