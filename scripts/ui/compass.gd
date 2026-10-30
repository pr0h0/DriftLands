class_name Compass
extends Control
## Optional heading marker at the top of the screen pointing to the nearest remaining shard.


func _process(_dt: float) -> void:
	visible = Settings.get_v("compass")
	if visible:
		queue_redraw()


func _draw() -> void:
	var s := get_tree().get_first_node_in_group("session") as Session
	var cam := get_viewport().get_camera_3d()
	if s == null or cam == null or s.level == null:
		return
	var target := s.compass_target(cam.global_position)
	if target == Vector3.INF:
		return
	var best_d := cam.global_position.distance_to(target)
	var local := cam.global_basis.inverse() * (target - cam.global_position)
	var ang := atan2(local.x, -local.z)
	var cx: float = size.x / 2.0 + clamp(ang / PI, -1.0, 1.0) * size.x * 0.32
	var y := 70.0
	var col := Color(0.75, 0.93, 1.0, 0.9)
	draw_colored_polygon(PackedVector2Array([Vector2(cx, y + 14), Vector2(cx - 9, y), Vector2(cx + 9, y)]), col)
	var font := get_theme_default_font()
	var txt := "%d m" % int(best_d)
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(font, Vector2(cx - w / 2.0, y + 32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
