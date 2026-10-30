class_name RunResults
extends CanvasLayer
## End of an endless run or a time trial: score, best, medal and what next.

signal again
signal quit_to_menu


func setup(r: Dictionary) -> RunResults:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UITheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.modulate.a = 0.0
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.45)
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
	var info := Label.new()
	if r["mode"] == "endless":
		v.add_child(UITheme.title_label("The wind lets you go", 52))
		info.text = "Islands reached  %d%s\nBest  %d\nTime  %s" % [r["islands"], "   · new best" if r["new_best"] else "", int(r["best"]), Levels.format_time(r["time"])]
	else:
		var m: Array = r["medals"]
		var medal := "Gold" if r["time"] <= m[0] else ("Silver" if r["time"] <= m[1] else ("Bronze" if r["time"] <= m[2] else ""))
		v.add_child(UITheme.title_label("Trial complete", 52))
		if medal != "":
			var ml := UITheme.title_label("%s medal" % medal, 36)
			ml.modulate = {"Gold": UITheme.GOLD, "Silver": Color(0.85, 0.88, 0.95), "Bronze": Color(0.9, 0.6, 0.4)}[medal]
			v.add_child(ml)
		info.text = "Time  %s%s\nBest  %s\nGold %s  ·  Silver %s  ·  Bronze %s" % [Levels.format_time(r["time"]), "   · new best" if r["new_best"] else "",
			Levels.format_time(float(r["best"])), Levels.format_time(m[0]), Levels.format_time(m[1]), Levels.format_time(m[2])]
	v.add_child(info)
	for u in r.get("unlocks", []):
		var ul := Label.new()
		ul.text = "Unlocked in the Wardrobe:  %s" % u
		ul.add_theme_color_override("font_color", UITheme.GOLD)
		v.add_child(ul)
	v.add_child(UITheme.button("Fly again", func(): again.emit()))
	v.add_child(UITheme.button("Main menu", func(): quit_to_menu.emit()))
	create_tween().tween_property(root, "modulate:a", 1.0, 1.0)
	return self
