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
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Palette.with_alpha(Palette.PANEL, 0.55)
	disabled.border_color = Palette.with_alpha(Palette.GOLD, 0.2)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_disabled_color", Palette.with_alpha(Palette.CREAM, 0.55))
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


## --- Cabeçalho / rodapé padrão das telas-meta -----------------------------

const TITLE_SIZE := 34
const SUBTITLE_SIZE := 16
const BACK_TEXT := "← Voltar"
const BACK_MIN := Vector2(160, 52)
const TITLE_FONT := preload("res://assets/fonts/Cinzel-Bold.ttf")


## Título: Cinzel dourado 34 com sombra. Não mexe em posição (cada cena decide).
static func style_title(title: Label) -> void:
	if title == null:
		return
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.add_theme_color_override("font_color", Palette.GOLD)
	title.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)


## Subtítulo: Noto creme 16.
static func style_subtitle(sub: Label) -> void:
	if sub == null:
		return
	sub.add_theme_font_size_override("font_size", SUBTITLE_SIZE)
	sub.add_theme_color_override("font_color", Palette.CREAM)


## Título no topo-esquerdo (24,12) e subtítulo logo abaixo (24,58).
## Para telas onde título/subtítulo são filhos diretos da raiz.
static func dock_header(title: Label, sub: Label) -> void:
	style_title(title)
	if title != null:
		title.set_anchors_preset(Control.PRESET_TOP_WIDE)
		title.offset_left = 24.0
		title.offset_right = -24.0
		title.offset_top = 6.0
		title.offset_bottom = 58.0
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	style_subtitle(sub)
	if sub != null:
		sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
		sub.offset_left = 24.0
		sub.offset_right = -24.0
		sub.offset_top = 60.0
		sub.offset_bottom = 88.0
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


## Voltar padrão: "← Voltar", ghost, sem quebra de linha.
static func style_back(btn: Button) -> void:
	if btn == null:
		return
	btn.text = BACK_TEXT
	btn.custom_minimum_size = BACK_MIN
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	btn.clip_text = false
	btn.add_theme_font_size_override("font_size", 20)
	apply_ghost(btn)


## Prende um botão no canto inferior-esquerdo da raiz (para botões fora de container).
static func dock_bottom_left(btn: Control) -> void:
	if btn == null:
		return
	btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	btn.offset_left = 24.0
	btn.offset_right = 24.0 + BACK_MIN.x
	btn.offset_top = -16.0 - BACK_MIN.y
	btn.offset_bottom = -16.0


## Monta o chrome padrão de uma tela-meta numa chamada: fundo vivo, cabeçalho
## topo-esquerdo, Voltar no canto inferior-esquerdo, CTA e press_bounce em todos
## os botões. `primary` e `sub` são opcionais.
static func setup_screen(root: Control, variant: String, title: Label, sub: Label,
		back: Button, primary: Button = null) -> MetaBackdrop:
	var backdrop: MetaBackdrop = MetaBackdrop.apply(root, variant)
	_place_header(root, title, sub)
	style_back(back)
	if back != null and back.get_parent() == root:
		dock_bottom_left(back)
	apply_cta(primary)
	UiMotion.bounce_all(root)
	return backdrop


static func _place_header(root: Control, title: Label, sub: Label) -> void:
	if title != null and title.get_parent() == root:
		dock_header(title, sub if sub != null and sub.get_parent() == root else null)
		return
	style_title(title)
	style_subtitle(sub)
