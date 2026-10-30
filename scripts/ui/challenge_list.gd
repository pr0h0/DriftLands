class_name ChallengeList
extends Control
## Live view of the level's fragments and three challenges.

var session: Session
var align_right := false
const ROW := 22.0


func _ready() -> void:
	custom_minimum_size = Vector2(250, ROW * 4 + 6)


func _process(_dt: float) -> void:
	queue_redraw()


func _rows() -> Array:
	var s := session
	if s == null or s.level == null or s.player == null:
		return []
	if s.level is RunLevel:
		return (s.level as RunLevel).hud_rows()
	var total := s.level.fragments.size()
	var found := Progress.fragments(s.level_id).size()
	var earned: Dictionary = Progress.level_info(s.level_id).get("challenges", {})
	var flaw_fail := s.player.falls > 0 or s.player.hits > 0
	var t := s.elapsed
	var par := s.level.par_time * Difficulty.par_scale()
	var need := Difficulty.fragments_needed(total)
	return [
		["Fragments  %d / %d" % [found, total], "done" if found >= total else "open", true],
		["Flawless (no falls or hits)", "fail" if flaw_fail else ("done" if earned.get("flawless", false) else "open"), false],
		["Under %s   ·   %s" % [Levels.format_time(par), Levels.format_time(t)], "fail" if t > par else ("done" if earned.get("time", false) else "open"), false],
		["Find every fragment" if need >= total else "Find %d fragments" % need, "done" if found >= need else "open", false],
	]


func _draw() -> void:
	var font := get_theme_default_font()
	var rows := _rows()
	for i in rows.size():
		var r: Array = rows[i]
		var y := 4.0 + i * ROW
		var text: String = r[0]
		var state: String = r[1]
		var header: bool = r[2]
		var size_px := 17 if header else 15
		var col := Color(1.0, 0.86, 0.55) if header else Color(1, 0.96, 0.9, 0.85)
		if state == "fail" and not header:
			col = Color(1, 0.62, 0.58, 0.85)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		var icon_x := size.x - 8.0 if align_right else 8.0
		var text_x := size.x - 22.0 - w if align_right else 22.0
		var cy := y + ROW / 2.0
		match state:
			"done":
				draw_circle(Vector2(icon_x, cy), 6.0, Color(0.55, 0.95, 0.65))
				draw_polyline(PackedVector2Array([Vector2(icon_x - 3, cy), Vector2(icon_x - 1, cy + 3), Vector2(icon_x + 3, cy - 3)]), Color(0.1, 0.25, 0.12), 1.8, true)
			"fail":
				draw_line(Vector2(icon_x - 4, cy - 4), Vector2(icon_x + 4, cy + 4), Color(1, 0.5, 0.45, 0.8), 2.0, true)
				draw_line(Vector2(icon_x - 4, cy + 4), Vector2(icon_x + 4, cy - 4), Color(1, 0.5, 0.45, 0.8), 2.0, true)
			_:
				draw_arc(Vector2(icon_x, cy), 5.5, 0, TAU, 20, Color(1, 1, 1, 0.6), 1.5, true)
		draw_string(font, Vector2(text_x, y + ROW - 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)
