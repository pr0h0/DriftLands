class_name LivesBar
extends Control
## Lives as small Wanderer silhouettes (Challenge mode) or "∞" in Practice.

var lives := 3
var maximum := 3
var unlimited := true


func _ready() -> void:
	custom_minimum_size = Vector2(110, 26)


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var col := Color(1, 0.96, 0.9, 0.9)
	draw_string(font, Vector2(0, size.y / 2.0 + 6), "Lives", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(col, 0.7))
	if unlimited:
		draw_string(font, Vector2(46, size.y / 2.0 + 8), "∞", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
		return
	for i in maximum:
		var x := 52.0 + i * 18.0
		var y := size.y / 2.0
		var on := i < lives
		var c := Color(0.85, 0.25, 0.2) if on else Color(1, 1, 1, 0.18)
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - 3), Vector2(x - 6, y + 9), Vector2(x + 6, y + 9)]), c)
		draw_circle(Vector2(x, y - 5), 4.0, Color(0.95, 0.9, 0.82) if on else Color(1, 1, 1, 0.18))
