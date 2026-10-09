extends CanvasLayer
## Overlay de transicao de cena — cortina diagonal de tinta com filete dourado.
##
## Um quadrilatero de aresta inclinada (~12 graus, levemente irregular) varre a
## tela da esquerda para a direita em `close()` e sai pelo lado direito em
## `open()`; o filete dourado acompanha a aresta que esta se movendo.
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

var _sweep: Sweep
var _tween: Tween
var _busy: bool = false


## Desenho da cortina. Separado do controle de tempo para a classe do overlay
## continuar só com a API (close/open/is_busy/set_busy).
class Sweep extends Control:
	const SLANT_DEG := 12.0
	const SEGMENTS := 8
	const MARGIN := 24.0
	## Desvio horizontal (px) por vértice da aresta: deixa o corte levemente torto.
	const JITTER: Array[float] = [0.0, 4.0, -3.0, 5.0, -4.0, 2.0, -5.0, 3.0, 0.0]

	## x (na base da tela) da aresta que avança e da que recua.
	var lead: float = 0.0:
		set(v):
			lead = v
			queue_redraw()
	var trail: float = 0.0:
		set(v):
			trail = v
			queue_redraw()
	## +1: filete na aresta que avança (close). -1: na que recua (open).
	var gold_side: int = 1

	## Tamanho do viewport (o Control pode ter size 0 antes do 1º layout).
	func _dim() -> Vector2:
		return get_viewport_rect().size

	func slant() -> float:
		return tan(deg_to_rad(SLANT_DEG)) * _dim().y

	func hidden_x() -> float:
		return -slant() - MARGIN

	func covered_x() -> float:
		return _dim().x + MARGIN

	func _edge(base: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var s: float = slant()
		for i in SEGMENTS + 1:
			var t: float = float(i) / float(SEGMENTS)
			pts.append(Vector2(base + s * (1.0 - t) + JITTER[i], _dim().y * t))
		return pts

	func _draw() -> void:
		if lead - trail < 1.0:
			return
		var lead_pts: PackedVector2Array = _edge(lead)
		var trail_pts: PackedVector2Array = _edge(trail)
		trail_pts.reverse()
		draw_colored_polygon(lead_pts + trail_pts, Palette.INK)
		var gold_pts: PackedVector2Array = lead_pts if gold_side > 0 else _edge(trail)
		draw_polyline(gold_pts, Palette.with_alpha(Palette.GOLD, 0.28), 9.0)
		draw_polyline(gold_pts, Palette.with_alpha(Palette.GOLD, 0.95), 3.0)


func _ready() -> void:
	layer = 4096
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_sweep = Sweep.new()
	_sweep.name = "Sweep"
	_sweep.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sweep.visible = false
	add_child(_sweep)


func is_busy() -> bool:
	return _busy


func set_busy(value: bool) -> void:
	_busy = value


func _restart_tween() -> Tween:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	return _tween


## Fecha a cortina (chama ANTES de trocar de cena). Aguarda o fim do tween.
func close(duration: float = DEFAULT_DURATION) -> void:
	if _sweep == null:
		return
	_sweep.mouse_filter = Control.MOUSE_FILTER_STOP
	_sweep.visible = true
	_sweep.gold_side = 1
	_sweep.trail = _sweep.hidden_x()
	_sweep.lead = _sweep.hidden_x()
	var tw: Tween = _restart_tween()
	tw.tween_property(_sweep, "lead", _sweep.covered_x(), duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished


## Reabre a cortina (chama DEPOIS de trocar de cena). Aguarda o fim do tween.
func open(duration: float = DEFAULT_DURATION) -> void:
	if _sweep == null:
		return
	_sweep.visible = true
	_sweep.gold_side = -1
	_sweep.lead = _sweep.covered_x()
	_sweep.trail = _sweep.hidden_x()
	var tw: Tween = _restart_tween()
	tw.tween_property(_sweep, "trail", _sweep.covered_x(), duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	_sweep.visible = false
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
