class_name CompleteScreen
extends CanvasLayer
## Shown after the beacon is lit: time, best time, and where to go next.

signal next_level
signal replay
signal quit_to_menu


func setup(level_id: int, time: float, new_best: bool, ch := {}, par := 0.0) -> CompleteScreen:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UITheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.modulate.a = 0.0
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.4)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var last := level_id >= Levels.count()
	var stars := StarRow.new().setup([ch.get("flawless", false), ch.get("time", false), ch.get("fragments", false)], 34.0)
	v.add_child(stars)
	stars.pop_in(0.9)
	var t2 := UITheme.title_label("Beacon lit" if not last else "The last light returns", 56)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t2)
	var info := Label.new()
	var best := float(Progress.level_info(level_id).get("best", time))
	info.text = "%s\nTime  %s%s\nBest  %s" % [Levels.LIST[level_id - 1]["title"], Levels.format_time(time),
		"   · new best" if new_best else "", Levels.format_time(best)]
	v.add_child(info)
	var chl := Label.new()
	chl.text = "Challenges\n  %s  Flawless: no falls, no hits\n  %s  Under %s\n  %s  All light fragments  (%d / %d)" % [
		"done" if ch.get("flawless", false) else "  —  ", "done" if ch.get("time", false) else "  —  ", Levels.format_time(par),
		"done" if ch.get("fragments", false) else "  —  ", Progress.fragments(level_id).size(), 5]
	chl.add_theme_font_size_override("font_size", 17)
	chl.modulate = Color(1, 0.92, 0.75)
	v.add_child(chl)
	if last:
		var thanks := Label.new()
		thanks.text = "You've lit every beacon in Driftlands.\nThank you for playing."
		thanks.modulate = UITheme.GOLD
		v.add_child(thanks)
	else:
		v.add_child(UITheme.button("Next: " + Levels.LIST[level_id]["title"], func(): next_level.emit()))
	v.add_child(UITheme.button("Play again", func(): replay.emit()))
	v.add_child(UITheme.button("Main menu", func(): quit_to_menu.emit()))
	create_tween().tween_property(root, "modulate:a", 1.0, 1.2)
	return self
