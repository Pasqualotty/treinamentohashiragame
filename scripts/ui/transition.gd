extends CanvasLayer
## Overlay de transicao de cena — cortina fade-to-ink com selo dourado no pico.
##
## Instanciada em runtime como filha persistente do autoload SceneRouter, por
## isso sobrevive a `change_scene_to_file` (so a current_scene e trocada —
## autoloads e seus filhos continuam vivos sob /root).
##
## Uso tipico (feito pelo SceneRouter):
##   await transition.close()   # cobre a tela antes de trocar de cena
##   get_tree().change_scene_to_file(path)
##   await transition.open()    # revela a cena nova

const DEFAULT_DURATION := 0.26
const SEAL_FADE := 0.16

var _curtain: ColorRect
var _seal: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 4096
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	var ink: Color = Palette.INK if _has_palette() else Color(0.02, 0.02, 0.03, 1.0)
	var gold: Color = Palette.GOLD if _has_palette() else Color(0.91, 0.72, 0.29, 1.0)

	_curtain = ColorRect.new()
	_curtain.name = "Curtain"
	_curtain.color = Color(ink.r, ink.g, ink.b, 0.0)
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_curtain)

	# Selo dourado — fina linha horizontal que acende no pico da cortina,
	# como um lampejo de lamina. Puramente decorativo.
	_seal = ColorRect.new()
	_seal.name = "Seal"
	_seal.color = Color(gold.r, gold.g, gold.b, 0.0)
	_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal.anchor_left = 0.0
	_seal.anchor_right = 1.0
	_seal.anchor_top = 0.5
	_seal.anchor_bottom = 0.5
	_seal.offset_top = -1.0
	_seal.offset_bottom = 1.0
	add_child(_seal)


func _has_palette() -> bool:
	return get_node_or_null("/root/Palette") != null


func is_busy() -> bool:
	return _busy


func set_busy(value: bool) -> void:
	_busy = value


## Fecha a cortina (chama ANTES de trocar de cena). Aguarda o fim do tween.
func close(duration: float = DEFAULT_DURATION) -> void:
	if _curtain == null:
		return
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw: Tween = create_tween()
	tw.tween_property(_curtain, "color:a", 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_seal, "color:a", 0.85, duration * 0.5) \
		.set_delay(duration * 0.4)
	await tw.finished
	_flash_seal_out()


func _flash_seal_out() -> void:
	if _seal == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(_seal, "color:a", 0.0, SEAL_FADE).set_trans(Tween.TRANS_SINE)


## Reabre a cortina (chama DEPOIS de trocar de cena). Aguarda o fim do tween.
func open(duration: float = DEFAULT_DURATION) -> void:
	if _curtain == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(_curtain, "color:a", 0.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
