class_name HudTrail
extends Control
## Rastro de dano: faixa clara entre o fim da vida atual e o valor anterior.
## Fica como filho da `ProgressBar` (desenha por cima do fundo, ao lado do fill).
## Ao tomar dano o rastro espera HOLD_SEC e então desce em SLIDE_SEC.
## Reutilizável por qualquer barra (brawl e duelo).

const HOLD_SEC: float = 0.35
const SLIDE_SEC: float = 0.4
const TRAIL_COLOR := Color(1.0, 0.86, 0.55, 0.85)

## Recuo lateral/vertical = margem interna do StyleBox de fundo da barra.
@export var inset: float = 3.0

var _bar: ProgressBar
var _trail: float = 0.0
var _last_value: float = 0.0
var _last_max: float = 0.0
var _hold: float = 0.0
var _rate: float = 0.0


## Cria o rastro como filho da barra e já o liga a ela.
static func attach(bar: ProgressBar, edge_inset: float = 3.0) -> HudTrail:
	var trail := HudTrail.new()
	trail.name = "HudTrail"
	trail.inset = edge_inset
	trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trail.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_child(trail)
	trail._bind(bar)
	return trail


## Valor (na unidade da barra) em que o rastro está agora.
func get_trail_value() -> float:
	return _trail


func _bind(bar: ProgressBar) -> void:
	_bar = bar
	_trail = bar.value
	_last_value = bar.value
	_last_max = bar.max_value


func _process(delta: float) -> void:
	if _bar == null:
		return
	_track_damage()
	_advance(delta)
	queue_redraw()


## Detecta queda de valor: arma a espera e a velocidade de descida.
func _track_damage() -> void:
	var value: float = _bar.value
	if not is_equal_approx(_bar.max_value, _last_max):
		_last_max = _bar.max_value # vida máxima mudou (setup do lutador): sem rastro
		_trail = value
		_last_value = value
		return
	if value < _last_value - 0.001:
		_hold = HOLD_SEC
		_rate = maxf(_trail - value, 0.0) / SLIDE_SEC
	_last_value = value
	if value > _trail:
		_trail = value


func _advance(delta: float) -> void:
	if _trail <= _bar.value:
		return
	if _hold > 0.0:
		_hold -= delta
		return
	_trail = maxf(_bar.value, _trail - _rate * delta)


func _draw() -> void:
	if _bar == null or _trail <= _bar.value or _bar.max_value <= 0.0:
		return
	var usable: float = size.x - inset * 2.0
	var x0: float = inset + usable * (_bar.value / _bar.max_value)
	var x1: float = inset + usable * (_trail / _bar.max_value)
	var h: float = size.y - inset * 2.0
	draw_rect(Rect2(x0, inset, maxf(x1 - x0, 0.0), h), TRAIL_COLOR)
