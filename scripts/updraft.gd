class_name Updraft
extends Area3D
## A wind vent: an ancient stone vent breathing a column of rising air. Lifts the player while
## gliding (hover with no input, sink with dive); lift fades toward the top, marked by a cloud crown.

var height := 40.0
var radius := 5.0
var strength := 9.0
var _ribbons: MeshInstance3D


func setup(h: float, r := 5.0, s := 9.0) -> Updraft:
	height = h
	radius = r
	strength = s
	return self


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.height = height + 8.0
	c.radius = radius
	cs.shape = c
	cs.position.y = c.height / 2.0 - 2.0
	add_child(cs)

	add_child(Assets.spawn("vent", true, 2))
	# Three spiraling wind bands climbing the column.
	var paths := []
	var turns := height / 9.0
	for k in 3:
		var path := PackedVector3Array()
		var n := int(turns * 24)
		for i in n + 1:
			var t := float(i) / n
			var a := k * TAU / 3.0 + t * turns * TAU
			var r := radius * (0.45 + 0.35 * t)
			path.append(Vector3(cos(a) * r, 0.3 + t * height, sin(a) * r))
		paths.append(path)
	_ribbons = FX.ribbons(paths, 0.5, Vector3.UP, Color(0.85, 0.95, 1.0), 0.55, 0.35, turns * 1.5)
	add_child(_ribbons)
	# Faint core haze so the column reads from far away.
	add_child(FX.beam(radius * 0.35, height, Color(0.8, 0.92, 1.0), 0.025))
	add_child(FX.swirl(radius * 0.6, height, Color(0.55, 0.8, 0.35), Color(1.0, 0.7, 0.8)))
	add_child(FX.streaks(radius * 0.5, height))
	# Cloud crown at the top of the lift.
	var crown := FX.lanterns(Vector3(radius * 0.8, 0.8, radius * 0.8), Color(1, 1, 1, 0.5), 24)
	(crown.draw_pass_1 as QuadMesh).size = Vector2(1.6, 1.6)
	var cm := (crown.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	cm.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	var tex := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.5))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	cm.albedo_texture = tex
	crown.position.y = height * 0.92
	add_child(crown)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = Sound.looped("wind_loop")
	snd.bus = "SFX"
	snd.unit_size = 5.0
	snd.max_distance = 45.0
	snd.volume_db = -10.0
	snd.position.y = 3.0
	snd.autoplay = true
	add_child(snd)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _process(dt: float) -> void:
	_ribbons.rotation.y += dt * 0.35


func lift_at(p: Vector3) -> float:
	var h := p.y - global_position.y
	return strength * (1.0 - smoothstep(height * 0.7, height, h))


func _on_enter(body: Node3D) -> void:
	if body is Player:
		body.updrafts.append(self)
		if not body.gliding:
			ElUtil.hint(self, "updraft", "Wind vents lift you while gliding. Let go of the keys to hover and rise; hold %s to sink back down." % Settings.key_label("sprint"))


func _on_exit(body: Node3D) -> void:
	if body is Player:
		body.updrafts.erase(self)
