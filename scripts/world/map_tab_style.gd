extends RefCounted
## Abas de mundo como chips: ativo em ouro, aberto em PANEL, trancado apagado com
## um cadeado desenhado pequeno (filho `LockGlyph`) à esquerda do texto.

const _Art := preload("res://scripts/world/map_node_art.gd")
const CHIP_MIN := Vector2(120.0, 38.0)
const FONT_SIZE := 15
const LOCK_PAD := 30.0


## "Mundo 2 — Trem" -> "Trem".
static func short_name(world_title: String) -> String:
	var parts: PackedStringArray = world_title.split("— ")
	return parts[parts.size() - 1].strip_edges()


## Aplica texto, estilo e cadeado. `open`: mundo liberado; `active`: mundo atual.
static func apply(btn: Button, world_id: String, world_title: String, open: bool, active: bool) -> void:
	btn.text = "%s %s" % [world_id.to_upper(), short_name(world_title)]
	btn.custom_minimum_size = CHIP_MIN
	btn.add_theme_font_size_override("font_size", FONT_SIZE)
	var font_col: Color = _font_color(open, active)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(key, font_col)
	for sname in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(sname, _style(open, active, sname, not open))
	_sync_lock(btn, not open)


static func _font_color(open: bool, active: bool) -> Color:
	if not open:
		return Palette.with_alpha(Palette.CREAM, 0.55)
	return Palette.INK if active else Palette.CREAM


static func _style(open: bool, active: bool, sname: String, locked: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(19)
	sb.set_border_width_all(1)
	sb.content_margin_left = LOCK_PAD if locked else 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	if active:
		sb.bg_color = Palette.GOLD_BRIGHT if sname == "hover" else Palette.GOLD
		sb.border_color = Palette.GOLD_BRIGHT
	elif open:
		sb.bg_color = Palette.with_alpha(Palette.PANEL, 0.85 if sname != "hover" else 0.95)
		sb.border_color = Palette.with_alpha(Palette.GOLD, 0.55 if sname != "hover" else 0.9)
	else:
		sb.bg_color = Palette.with_alpha(Palette.PANEL, 0.6)
		sb.border_color = Palette.with_alpha(Palette.CREAM, 0.25)
	return sb


static func _sync_lock(btn: Button, locked: bool) -> void:
	var glyph: Control = btn.get_node_or_null("LockGlyph") as Control
	if glyph == null:
		if not locked:
			return
		glyph = preload("res://scripts/world/lock_glyph.gd").new()
		glyph.name = "LockGlyph"
		btn.add_child(glyph)
	glyph.visible = locked
