class_name StarRow
extends Control
## Three challenge stars: gold when earned, hollow outline when not. Optionally pops them in.

var earned: Array = [false, false, false]
var star_size := 18.0
var gap := 6.0
var _scale: Array = [1.0, 1.0, 1.0]


func setup(e: Array, size_px := 18.0) -> StarRow:
	earned = e
	star_size = size_px
	gap = size_px * 0.6
	custom_minimum_size = Vector2(3 * size_px * 2.0 + 2 * gap, size_px * 2.1)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


## Earned stars grow in one after another (with a chime); call once visible.
func pop_in(delay := 0.4) -> void:
	for i in 3:
		_scale[i] = 0.0 if earned[i] else 1.0
	queue_redraw()
	for i in 3:
		if not earned[i]:
			continue
		var t := create_tween()
		t.tween_interval(delay + i * 0.35)
		t.tween_callback(func(): Sound.play("fragment", -4.0, 0.9 + i * 0.12))
		t.tween_method(func(v): _scale[i] = v; queue_redraw(), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func star_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


func _draw() -> void:
	var r := star_size
	var total := 3 * r * 2.0 + 2 * gap
	var x0 := (size.x - total) / 2.0 + r
	for i in 3:
		var c := Vector2(x0 + i * (r * 2.0 + gap), size.y / 2.0 + r * 0.08)
		var outline := star_points(c, r)
		outline.append(outline[0])
		draw_polyline(outline, Color(1, 0.92, 0.75, 0.55), max(1.5, r * 0.08), true)
		if earned[i] and _scale[i] > 0.01:
			var s: float = _scale[i]
			draw_colored_polygon(star_points(c, r * s), Color(1.0, 0.8, 0.3))
			draw_colored_polygon(star_points(c + Vector2(-r * 0.12, -r * 0.15) * s, r * 0.45 * s), Color(1, 0.95, 0.7, 0.6))
			draw_circle(c, r * 1.4 * s, Color(1.0, 0.8, 0.3, 0.08))
