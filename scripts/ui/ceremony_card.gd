class_name CeremonyCard
extends CanvasLayer
## Cerimônia em tela cheia: intro de fase (`play`), faixa de onda (`play_wave`)
## e fase concluída (`play_clear`). Letterbox de tinta + título em Cinzel,
## paleta índigo/carmesim/ouro de `Palette`. Em headless nada é desenhado.

## Camada 9: logo abaixo do CombatHud (10) — as barras de tinta não escondem vida/respiração.
const LAYER: int = 9
const FONT_TITLE := "res://assets/fonts/Cinzel-Bold.ttf"
const FONT_BOLD := "res://assets/fonts/NotoSans-Bold.ttf"
const FONT_BODY := "res://assets/fonts/NotoSans-Regular.ttf"
const COIN_ICON := "res://assets/ui/icons/coin.png"
const BAR_H: float = 84.0
const SLIDE_PX: float = 24.0
const IN_SEC: float = 0.25
const OUT_SEC: float = 0.25
const WAVE_SEC: float = 1.2
const COUNT_SEC: float = 0.6


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


## Intro de fase: kicker dourado, filete carmesim, título Cinzel, subtítulo.
func play(kicker: String, title: String, subtitle: String, duration: float) -> void:
	if is_headless():
		queue_free()
		return
	layer = LAYER
	var bars: Array[ColorRect] = _add_letterbox()
	var box: VBoxContainer = _add_content_box()
	box.add_child(_kicker_label(kicker))
	box.add_child(_rule())
	box.add_child(_text_label(title, FONT_TITLE, 44, Palette.CREAM, true))
	if not subtitle.is_empty():
		box.add_child(_text_label(subtitle, FONT_BODY, 18, Palette.with_alpha(Palette.CREAM, 0.82), false, true))
	await _run_timeline(bars, box, maxf(0.6, duration))
	queue_free()


## Faixa curta no topo ("ONDA 2 / 3"), sem letterbox.
func play_wave(current: int, total: int) -> void:
	if is_headless():
		queue_free()
		return
	layer = LAYER
	var band := ColorRect.new()
	band.color = Palette.with_alpha(Palette.INK, 0.62)
	band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	band.offset_top = 176.0
	band.offset_bottom = 222.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var lbl := _text_label("ONDA %d / %d" % [current, total], FONT_TITLE, 28, Palette.GOLD_BRIGHT, true)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(lbl)
	band.modulate.a = 0.0
	band.position.x = -SLIDE_PX
	var tw := create_tween()
	tw.tween_property(band, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(band, "position:x", 0.0, 0.18)
	tw.tween_interval(WAVE_SEC - 0.4)
	tw.tween_property(band, "modulate:a", 0.0, 0.22)
	await tw.finished
	queue_free()


## Fim de fase: título, moedas em count-up (0.6 s) e XP.
func play_clear(coins: int, xp: int) -> void:
	if is_headless():
		queue_free()
		return
	layer = LAYER
	var bars: Array[ColorRect] = _add_letterbox()
	var box: VBoxContainer = _add_content_box()
	box.add_child(_kicker_label("Missão cumprida"))
	box.add_child(_rule())
	box.add_child(_text_label("FASE CONCLUÍDA", FONT_TITLE, 52, Palette.GOLD_BRIGHT, true))
	var coin_lbl: Label = _text_label("", FONT_BOLD, 30, Palette.GOLD, true)
	box.add_child(_coin_row(coin_lbl))
	box.add_child(_text_label("+%d XP" % xp, FONT_BOLD, 22, Palette.WATER_BRIGHT, true))
	await _run_timeline(bars, box, 2.0, func() -> void: _count_up(coin_lbl, coins))
	queue_free()


## --- Linha do tempo -----------------------------------------------------

func _run_timeline(bars: Array[ColorRect], box_in: Control, duration: float, on_in: Callable = Callable()) -> void:
	var box: Control = box_in.get_parent() as Control # CenterContainer: fora de container, aceita position
	box.modulate.a = 0.0
	box.position.y = SLIDE_PX
	var tw := create_tween().set_parallel(true)
	tw.tween_property(bars[0], "position:y", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(bars[1], "position:y", _view_h() - BAR_H, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "modulate:a", 1.0, IN_SEC)
	tw.tween_property(box, "position:y", 0.0, IN_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	if on_in.is_valid():
		on_in.call()
	await get_tree().create_timer(maxf(0.3, duration - IN_SEC - OUT_SEC - 0.1)).timeout
	var out := create_tween().set_parallel(true)
	out.tween_property(box, "modulate:a", 0.0, OUT_SEC)
	out.tween_property(bars[0], "modulate:a", 0.0, OUT_SEC)
	out.tween_property(bars[1], "modulate:a", 0.0, OUT_SEC)
	await out.finished


func _count_up(lbl: Label, target: int) -> void:
	if target <= 0:
		lbl.text = "Sem moedas nesta fase"
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: lbl.text = "+%d" % int(round(v)), 0.0, float(target), COUNT_SEC)


## --- Construção ---------------------------------------------------------

func _view_h() -> float:
	return 720.0 if get_viewport() == null else get_viewport().get_visible_rect().size.y


func _add_letterbox() -> Array[ColorRect]:
	var top := _bar(Control.PRESET_TOP_WIDE, -BAR_H)
	var bottom := _bar(Control.PRESET_TOP_WIDE, _view_h())
	return [top, bottom]


func _bar(preset: int, y: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Palette.with_alpha(Palette.INK, 0.94)
	r.set_anchors_preset(preset)
	r.offset_bottom = BAR_H
	r.position.y = y
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _add_content_box() -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(760, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	return box


func _kicker_label(text: String) -> Label:
	var fv := FontVariation.new()
	fv.base_font = load(FONT_BOLD) as Font
	fv.spacing_glyph = 4
	var lbl := _text_label(text.to_upper(), "", 15, Palette.GOLD, false)
	lbl.add_theme_font_override("font", fv)
	return lbl


func _rule() -> Control:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ColorRect.new()
	line.color = Palette.CRIMSON
	line.custom_minimum_size = Vector2(180, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	return holder


func _text_label(text: String, font_path: String, size: int, color: Color, shadow: bool, wrap: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not font_path.is_empty() and ResourceLoader.exists(font_path):
		lbl.add_theme_font_override("font", load(font_path) as Font)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	if shadow:
		lbl.add_theme_color_override("font_shadow_color", Palette.SHADOW)
		lbl.add_theme_constant_override("shadow_offset_x", 2)
		lbl.add_theme_constant_override("shadow_offset_y", 3)
	return lbl


func _coin_row(lbl: Label) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(COIN_ICON):
		icon.texture = load(COIN_ICON) as Texture2D
	row.add_child(icon)
	row.add_child(lbl)
	return row
