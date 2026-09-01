class_name CeremonyCard
extends CanvasLayer
## Cartão central de cerimônia (intro de fase / onda limpa / fase concluída).
## Visual do protótipo web: kicker + título + subtítulo.

const LAYER: int = 90


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func play(kicker: String, title: String, subtitle: String, duration: float) -> void:
	layer = LAYER
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.07, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -220.0
	panel.offset_top = -90.0
	panel.offset_right = 220.0
	panel.offset_bottom = 90.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.88)
	sb.border_color = Color(0.35, 0.38, 0.45, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var k := Label.new()
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.text = kicker.to_upper()
	k.add_theme_font_size_override("font_size", 13)
	k.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78, 1.0))
	col.add_child(k)

	var t := Label.new()
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.text = title
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98, 1.0))
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	col.add_child(t)

	if not subtitle.is_empty():
		var s := Label.new()
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.text = subtitle
		s.add_theme_font_size_override("font_size", 16)
		s.add_theme_color_override("font_color", Color(0.7, 0.74, 0.8, 1.0))
		col.add_child(s)

	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(dim, "color:a", 0.28, 0.18)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_interval(maxf(0.35, duration - 0.5))
	tw.tween_property(panel, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(dim, "color:a", 0.0, 0.22)
	await tw.finished
	queue_free()
