class_name StageChrome
extends RefCounted
## Helpers do "chrome" da fase: detecção de toque, spawn fora do joystick,
## dica de teclado (só desktop) e texto de objetivo. Extraído do StageController
## para não inflar o arquivo — tudo aqui é estático e sem estado de cena.

## Primeiro X em que o caçador pode nascer quando há controles de toque
## (o joystick fica centrado em x≈150 e o botão de pulo em x≈285).
const SPAWN_MIN_X: float = 380.0
const HINT_LAYER: int = 45
const HINT_Y: float = 680.0
const HINT_SECONDS: float = 6.0
const HINT_TEXT: String = "A/D mover · Espaço pulo · Shift dash · Z atk · X/C skills · V ult · Esc pausa"

## -1 = automático; 0 = força desktop; 1 = força toque (smokes e capturas).
static var force_touch: int = -1


static func is_touch_device() -> bool:
	if force_touch >= 0:
		return force_touch == 1
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


## X final do spawn: empurra para a direita do joystick só quando há toque.
static func spawn_x(current_x: float, touch: bool) -> float:
	if touch and current_x < SPAWN_MIN_X:
		return SPAWN_MIN_X
	return current_x


static func objective_text(use_waves: bool, boss: bool = false) -> String:
	if boss:
		return "Derrote o chefe · a saída abre no fim"
	if use_waves:
		return "Elimine as ondas · a saída abre no fim"
	return "Derrote os onis e alcance a saída"


## Chip discreto de teclado na base da tela. Não faz nada em dispositivo de toque.
static func build_controls_hint(host: Node) -> CanvasLayer:
	if is_touch_device():
		return null
	var layer := CanvasLayer.new()
	layer.name = "ControlsHint"
	layer.layer = HINT_LAYER
	host.add_child(layer)
	var lbl := Label.new()
	lbl.name = "ControlsHintLabel"
	lbl.anchor_left = 0.0
	lbl.anchor_right = 1.0
	lbl.offset_left = 0.0
	lbl.offset_right = 0.0
	lbl.offset_top = HINT_Y - 18.0
	lbl.offset_bottom = HINT_Y + 18.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Palette.CREAM)
	lbl.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.text = HINT_TEXT
	lbl.modulate.a = 0.8
	layer.add_child(lbl)
	_fade_out_later(layer, lbl)
	return layer


static func _fade_out_later(layer: CanvasLayer, lbl: Label) -> void:
	var tw: Tween = layer.create_tween()
	tw.tween_interval(HINT_SECONDS)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(layer.queue_free)
