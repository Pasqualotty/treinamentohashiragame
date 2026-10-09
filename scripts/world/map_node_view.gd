extends Control
## Visual de um nó de fase no mapa: medalhão (textura por estado) + ícone de estado
## centralizado + chip de rótulo ABAIXO do medalhão. A origem do nó é o centro do
## medalhão (escalar o nó pulsa em torno dele). Não recebe toque — o `Button` flat
## do WorldMap continua sendo a área de toque.

const _Art := preload("res://scripts/world/map_node_art.gd")
const _CinzelFont := preload("res://assets/fonts/Cinzel-Bold.ttf")

const NUMBER_SIZE := 34
const CHIP_FONT_SIZE := 14
const CHIP_GAP := 8.0
const ENTER_TIME := 0.32
const ENTER_FROM := Vector2(0.8, 0.8)

var is_boss: bool = false
var state_kind: String = "locked"
var _number: String = ""
var _label: String = ""
var _tex: TextureRect
## Camada do ícone: filho DEPOIS do medalhão (o _draw do próprio nó sairia por baixo da textura).
var _icon: Control
var _chip: PanelContainer
var _chip_label: Label
## Retângulo do disco visível (global) — o chip nunca invade isto.
var _disc: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Monta os filhos. `kind`: available | cleared | locked.
func setup(boss: bool, label: String, number: String, kind: String) -> void:
	is_boss = boss
	_label = label
	_number = number
	state_kind = kind
	size = Vector2.ZERO
	_build_children()
	apply_kind(kind)


func _build_children() -> void:
	var disc_d: float = _Art.disc_size(is_boss)
	_disc = Control.new()
	_disc.name = "MedalDisc"
	_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disc.position = Vector2(-disc_d, -disc_d) * 0.5
	_disc.size = Vector2(disc_d, disc_d)
	add_child(_disc)

	var side: float = _Art.texture_side(is_boss)
	_tex = TextureRect.new()
	_tex.name = "Medal"
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_tex.size = Vector2(side, side)
	_tex.position = Vector2(-side, -side) * 0.5
	add_child(_tex)
	_icon = Control.new()
	_icon.name = "StateIcon"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(_paint_icon)
	add_child(_icon)
	_build_chip(disc_d)


func _build_chip(disc_d: float) -> void:
	_chip = PanelContainer.new()
	_chip.name = "LabelChip"
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.add_theme_stylebox_override("panel", _chip_style())
	_chip_label = Label.new()
	_chip_label.text = _label
	_chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip_label.add_theme_font_size_override("font_size", CHIP_FONT_SIZE)
	_chip_label.add_theme_color_override("font_color", Palette.CREAM)
	_chip.add_child(_chip_label)
	add_child(_chip)
	# Espinhos do chefe passam do disco: o chip desce um pouco mais.
	var gap: float = CHIP_GAP + (6.0 if is_boss else 0.0)
	var cs: Vector2 = _chip.get_combined_minimum_size()
	_chip.size = cs
	_chip.position = Vector2(-cs.x * 0.5, disc_d * 0.5 + gap)


func _chip_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.with_alpha(Palette.PANEL, 0.85)
	sb.border_color = Palette.with_alpha(Palette.GOLD, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	return sb


func apply_kind(kind: String) -> void:
	state_kind = kind
	if _tex != null:
		_tex.texture = _Art.medal_texture(kind, is_boss)
	if _chip_label != null:
		_chip_label.add_theme_color_override("font_color", _chip_font_color())
	if _icon != null:
		_icon.queue_redraw()


func _chip_font_color() -> Color:
	match state_kind:
		"locked":
			return Palette.with_alpha(Palette.CREAM, 0.6)
		"cleared":
			return Palette.CREAM
		_:
			return Palette.GOLD_BRIGHT


## Retângulo global do disco do medalhão.
func medal_rect() -> Rect2:
	return _disc.get_global_rect() if _disc != null else Rect2()


## Retângulo global do chip de rótulo.
func chip_rect() -> Rect2:
	return _chip.get_global_rect() if _chip != null else Rect2()


func _paint_icon() -> void:
	var h: float = _Art.disc_size(is_boss) * 0.5
	match state_kind:
		"locked":
			_Art.draw_lock(_icon, Vector2(0.0, -h * 0.28), h * 0.95, Color(0.78, 0.8, 0.84, 0.95))
		"cleared":
			_Art.draw_check(_icon, Vector2.ZERO, h * 0.95, Palette.CREAM)
		_:
			_draw_available(h)


func _draw_available(h: float) -> void:
	if is_boss:
		_Art.draw_seal(_icon, Vector2.ZERO, h * 0.95, Palette.GOLD_BRIGHT)
		return
	var fs: int = NUMBER_SIZE
	var baseline := Vector2(-h, fs * 0.36)
	_icon.draw_string(_CinzelFont, baseline + Vector2(0, 2), _number, HORIZONTAL_ALIGNMENT_CENTER, h * 2.0, fs,
		Palette.with_alpha(Palette.INK, 0.7))
	_icon.draw_string(_CinzelFont, baseline, _number, HORIZONTAL_ALIGNMENT_CENTER, h * 2.0, fs, Palette.GOLD_BRIGHT)


## Entrada do mapa: fade + escala 0.8 -> 1.0 com atraso (stagger).
func play_enter(delay: float) -> void:
	modulate.a = 0.0
	scale = ENTER_FROM
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, ENTER_TIME).set_delay(delay)
	tw.tween_property(self, "scale", Vector2.ONE, ENTER_TIME).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pop ao tocar: 1.1 e volta (a viagem já está a caminho).
func pop() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2(1.1, 1.1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
