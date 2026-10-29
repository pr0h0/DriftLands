class_name HeartsBar
extends Control
## Heart icons: filled for remaining health, hollow for lost.

var current := 3
var maximum := 3
var flash := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(maximum * 30 + 4, 28)


func _process(dt: float) -> void:
	flash = max(0.0, flash - dt * 2.0)
	queue_redraw()


static func heart_points(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 40:
		var t := float(i) / 40.0 * TAU
		# Classic heart curve, scaled to roughly `s` pixels wide.
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(c + Vector2(x, y) * s / 34.0)
	return pts


func _draw() -> void:
	for i in maximum:
		var c := Vector2(14 + i * 30, size.y / 2.0 + 1)
		var pts := heart_points(c, 24.0 * (1.0 + (flash * 0.25 if i == current else 0.0)))
		if i < current:
			draw_colored_polygon(pts, Color(1.0, 0.42, 0.45))
			draw_colored_polygon(heart_points(c + Vector2(-3, -3), 8.0), Color(1, 1, 1, 0.35))
		else:
			draw_colored_polygon(pts, Color(0, 0, 0, 0.25))
		var o := pts.duplicate()
		o.append(pts[0])
		draw_polyline(o, Color(1, 0.93, 0.88, 0.9), 1.5, true)
