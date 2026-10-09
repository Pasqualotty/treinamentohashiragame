class_name BrawlHudChrome
extends RefCounted
## Chrome do HUD do brawl: painel do caçador, barras com rastro/ticks e chip do tempo.
## Só constrói e estiliza; quem atualiza valores é `brawl_hud.gd`.

const FONT_TITLE := "res://assets/fonts/Cinzel-Bold.ttf"
const FONT_BODY := "res://assets/fonts/NotoSans-Regular.ttf"
const _UiFont := preload("res://scripts/ui/ui_font.gd")
const BLOCK_W: float = 360.0
const HP_H: float = 20.0
const BREATH_H: float = 12.0
const BAR_INSET: float = 3.0
const BORDER_PEER: float = 0.6
const BORDER_LOCAL: float = 0.95
const BREATH_SEGMENTS: int = 4


## Bloco de um caçador. Chaves: panel, name, hp_text, hp, breath.
static func make_block() -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(BLOCK_W, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_panel(panel, false)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 3)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(header)
	var name_lbl := make_name_label()
	header.add_child(name_lbl)
	var hp_text := make_hp_text()
	header.add_child(hp_text)
	var hp := make_hp_bar()
	inner.add_child(hp)
	var breath := make_breath_bar()
	inner.add_child(breath)
	return {"panel": panel, "name": name_lbl, "hp_text": hp_text, "hp": hp, "breath": breath}


## Painel translúcido com borda ouro; o do jogador local tem a borda mais forte.
static func style_panel(panel: PanelContainer, local: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.with_alpha(Palette.PANEL, 0.78)
	sb.border_color = Palette.with_alpha(Palette.GOLD, BORDER_LOCAL if local else BORDER_PEER)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 7
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	panel.add_theme_stylebox_override("panel", sb)


static func make_name_label() -> Label:
	var lbl := Label.new()
	lbl.name = "NameLabel"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.text = "Caçador"
	var fv := FontVariation.new()
	fv.base_font = load(FONT_TITLE) as Font
	fv.spacing_space = _UiFont.SPACE_PAD_PX
	lbl.add_theme_font_override("font", fv)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Palette.CREAM)
	lbl.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	return lbl


static func make_hp_text() -> Label:
	var lbl := Label.new()
	lbl.name = "HpText"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", load(FONT_BODY) as Font)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Palette.CREAM)
	lbl.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	return lbl


## Barra de vida: fundo CRIMSON_DIM, fill de rampa (pintado por `_paint_hp`) e rastro.
static func make_hp_bar() -> ProgressBar:
	var bar := _bar_base(HP_H)
	var bg := _bar_bg(Palette.with_alpha(Palette.CRIMSON_DIM, 0.95), 8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.CRIMSON
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	HudTrail.attach(bar, BAR_INSET)
	return bar


## Barra de respiração fina com 4 marcas de segmento.
static func make_breath_bar() -> ProgressBar:
	var bar := _bar_base(BREATH_H)
	var bg := _bar_bg(Palette.with_alpha(Palette.INK, 0.88), 6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.WATER
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	var ticks := BarTicks.new()
	ticks.segments = BREATH_SEGMENTS
	ticks.inset = BAR_INSET
	ticks.set_anchors_preset(Control.PRESET_FULL_RECT)
	ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(ticks)
	return bar


## Chip do cronômetro (PanelContainer + Label "TimeLabel" em Cinzel 28 ouro).
static func make_time_chip() -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = "TimeChip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.with_alpha(Palette.PANEL, 0.78)
	sb.border_color = Palette.with_alpha(Palette.GOLD, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	chip.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.name = "TimeLabel"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", load(FONT_TITLE) as Font)
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Palette.GOLD)
	lbl.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.text = "1:30"
	chip.add_child(lbl)
	return chip


static func _bar_base(height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


static func _bar_bg(color: Color, radius: int) -> StyleBoxFlat:
	var bg := StyleBoxFlat.new()
	bg.bg_color = color
	bg.border_color = Palette.with_alpha(Palette.GOLD, 0.5)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(radius)
	return bg
