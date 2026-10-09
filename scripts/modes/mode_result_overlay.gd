class_name ModeResultOverlay
extends Control
## Tela de resultado dos modos (brawl e duelo): escurece o fundo, letterbox de tinta,
## título Cinzel ouro com slide, subtítulo e dois botões lado a lado (CTA + ghost).
## Os helpers estáticos (`add_letterbox`, `style_title`, `bounce`, `slide_in`)
## também servem ao duelo, cujo resultado vive no `.tscn`.

const FONT_TITLE := "res://assets/fonts/Cinzel-Bold.ttf"
const FONT_BODY := "res://assets/fonts/NotoSans-Regular.ttf"
const _UiFont := preload("res://scripts/ui/ui_font.gd")
const BAR_H: float = 84.0
const DIM_ALPHA: float = 0.55
const SLIDE_PX: float = 24.0
const IN_SEC: float = 0.3
const PRESS_SCALE: float = 0.96

var _title: Label
var _subtitle: Label
var _primary: Button
var _secondary: Button
var _content: Control


## Monta o overlay completo. Callables inválidos viram botão sem ação.
static func build(title: String, subtitle: String, primary_text: String, secondary_text: String,
		on_primary: Callable, on_secondary: Callable, title_size: int = 44) -> ModeResultOverlay:
	var ov := ModeResultOverlay.new()
	ov.name = "EndOverlay"
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.process_mode = Node.PROCESS_MODE_ALWAYS
	ov._build(title, subtitle, primary_text, secondary_text, on_primary, on_secondary, title_size)
	return ov


func set_texts(title: String, subtitle: String) -> void:
	_title.text = title
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()


func get_buttons() -> Array[Button]:
	return [_primary, _secondary]


func get_title_label() -> Label:
	return _title


## Toca a entrada: letterbox some do nada, conteúdo desliza 24 px e aparece.
func play_in() -> void:
	_content.modulate.a = 0.0
	_content.position.y = SLIDE_PX
	slide_in(_content, IN_SEC)


## Título Cinzel no tamanho pedido, com sombra de tinta.
static func style_title(lbl: Label, size: int, color: Color) -> void:
	var fv := FontVariation.new()
	fv.base_font = load(FONT_TITLE) as Font
	fv.spacing_space = _UiFont.SPACE_PAD_PX
	lbl.add_theme_font_override("font", fv)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 3)


## Barras de tinta no topo e na base (ancoradas, sem interceptar clique).
static func add_letterbox(parent: Control) -> Array[ColorRect]:
	var bars: Array[ColorRect] = []
	for preset: int in [Control.PRESET_TOP_WIDE, Control.PRESET_BOTTOM_WIDE]:
		var bar := ColorRect.new()
		bar.name = "LetterboxTop" if preset == Control.PRESET_TOP_WIDE else "LetterboxBottom"
		bar.color = Palette.with_alpha(Palette.INK, 0.94)
		bar.set_anchors_preset(preset)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(bar)
		bars.append(bar)
	bars[0].offset_bottom = BAR_H
	bars[1].offset_top = -BAR_H
	return bars


## Sobe 24 px e faz fade-in do controle (position:y precisa ser definido antes).
static func slide_in(ctrl: Control, sec: float) -> void:
	var tw := ctrl.create_tween().set_parallel(true)
	tw.tween_property(ctrl, "modulate:a", 1.0, sec)
	tw.tween_property(ctrl, "position:y", 0.0, sec).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Bounce de botão: encolhe a 0.96 ao pressionar e volta ao soltar.
static func bounce(btn: Button) -> void:
	btn.button_down.connect(func() -> void: _scale_to(btn, PRESS_SCALE))
	btn.button_up.connect(func() -> void: _scale_to(btn, 1.0))


static func _scale_to(btn: Button, target: float) -> void:
	btn.pivot_offset = btn.size * 0.5
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2(target, target), 0.08)


func _build(title: String, subtitle: String, primary_text: String, secondary_text: String,
		on_primary: Callable, on_secondary: Callable, title_size: int) -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, DIM_ALPHA)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	add_letterbox(self)
	_content = _build_content(title_size)
	set_texts(title, subtitle)
	_primary = _make_button(primary_text, true, on_primary)
	_secondary = _make_button(secondary_text, false, on_secondary)
	var row := _content.find_child("Row", true, false) as HBoxContainer
	row.add_child(_primary)
	row.add_child(_secondary)


func _build_content(title_size: int) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(620, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	style_title(_title, title_size, Palette.GOLD)
	box.add_child(_title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_override("font", load(FONT_BODY) as Font)
	_subtitle.add_theme_font_size_override("font_size", 18)
	_subtitle.add_theme_color_override("font_color", Palette.with_alpha(Palette.CREAM, 0.85))
	box.add_child(_subtitle)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	return center # o CenterContainer é filho de Control puro: aceita position/modulate


func _make_button(text: String, primary: bool, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(240, 60)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.add_theme_font_size_override("font_size", 22)
	if primary:
		MetaChrome.apply_cta(btn)
	else:
		MetaChrome.apply_ghost(btn)
	bounce(btn)
	if action.is_valid():
		btn.pressed.connect(action)
	return btn
