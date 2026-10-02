class_name MetaChrome
extends RefCounted
## Placas da tela de diário — mesma tinta do hub, sem botão cinza do Godot.


static func apply_cta(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.GOLD
	normal.border_color = Palette.with_alpha(Palette.INK, 0.85)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Palette.GOLD_BRIGHT
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Palette.GOLD.darkened(0.22)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = Palette.WATER_BRIGHT
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Palette.with_alpha(Palette.GOLD_DIM, 0.55)
	disabled.border_color = Palette.with_alpha(Palette.INK, 0.35)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Palette.NIGHT_BG)
	btn.add_theme_color_override("font_hover_color", Palette.INK)
	btn.add_theme_color_override("font_pressed_color", Palette.INK)
	btn.add_theme_color_override("font_focus_color", Palette.NIGHT_BG)
	btn.add_theme_color_override("font_disabled_color", Palette.with_alpha(Palette.CREAM, 0.45))


static func apply_ghost(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.with_alpha(Palette.PANEL, 0.88)
	normal.border_color = Palette.with_alpha(Palette.GOLD, 0.45)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Palette.GOLD
	hover.bg_color = Palette.with_alpha(Palette.PANEL, 0.96)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Palette.with_alpha(Palette.INK, 0.55)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = Palette.WATER_BRIGHT
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_color_override("font_color", Palette.CREAM)
	btn.add_theme_color_override("font_hover_color", Palette.GOLD_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", Palette.CREAM)
	btn.add_theme_color_override("font_focus_color", Palette.CREAM)


static func card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.with_alpha(Palette.PANEL, 0.92)
	style.border_color = Palette.with_alpha(Palette.GOLD, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


static func apply_line_edit(edit: LineEdit) -> void:
	if edit == null:
		return
	var field := StyleBoxFlat.new()
	field.bg_color = Palette.with_alpha(Palette.NIGHT_BG, 0.95)
	field.border_color = Palette.with_alpha(Palette.GOLD, 0.45)
	field.set_border_width_all(2)
	field.set_corner_radius_all(10)
	field.content_margin_left = 16
	field.content_margin_right = 16
	field.content_margin_top = 12
	field.content_margin_bottom = 12
	var focus := field.duplicate() as StyleBoxFlat
	focus.border_color = Palette.GOLD
	edit.add_theme_stylebox_override("normal", field)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_color_override("font_color", Palette.CREAM)
	edit.add_theme_color_override("font_placeholder_color", Palette.with_alpha(Palette.CREAM, 0.35))
	edit.add_theme_color_override("caret_color", Palette.GOLD)
