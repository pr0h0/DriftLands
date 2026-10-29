class_name ShardMeter
extends Control
## The level's shards as diamonds; filled ones have been returned.

var total := 3
var count := 0
var pulse := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(130, 44)


func _process(dt: float) -> void:
	pulse = max(0.0, pulse - dt)
	queue_redraw()


func _draw() -> void:
	var spacing := 34.0
	var start := size.x / 2.0 - spacing * (total - 1) / 2.0
	for i in total:
		var c := Vector2(start + i * spacing, size.y / 2.0)
		var r := 9.0 + (pulse * 6.0 if i == count - 1 else 0.0)
		var pts := PackedVector2Array([c + Vector2(0, -r * 1.4), c + Vector2(r, 0), c + Vector2(0, r * 1.4), c + Vector2(-r, 0)])
		if i < count:
			draw_colored_polygon(pts, Color(0.75, 0.93, 1.0, 0.95))
			draw_circle(c, r * 2.2, Color(0.5, 0.85, 1.0, 0.08))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(1, 1, 1, 0.8), 1.5, true)
