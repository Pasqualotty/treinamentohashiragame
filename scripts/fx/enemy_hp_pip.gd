class_name EnemyHpPip
extends Node2D
## Barra verde de HP sobre o oni — igual ao protótipo (sempre visível).

const BAR_W: float = 40.0
const BAR_H: float = 5.0

var _ratio: float = 1.0
var _boss: bool = false


static func attach(host: Node2D, hp_label: Label, max_hp: int, offset_y: float = -78.0, boss: bool = false) -> EnemyHpPip:
	var pip := EnemyHpPip.new()
	host.add_child(pip)
	pip.setup(offset_y, boss)
	pip.set_ratio(max_hp, max_hp)
	if hp_label:
		hp_label.visible = false
	return pip


func setup(offset_y: float = -78.0, boss: bool = false) -> void:
	position = Vector2(0.0, offset_y)
	_boss = boss
	z_index = 20
	queue_redraw()


func set_ratio(current: int, max_hp: int) -> void:
	var m: int = maxi(max_hp, 1)
	_ratio = clampf(float(current) / float(m), 0.0, 1.0)
	visible = current > 0
	queue_redraw()


func _draw() -> void:
	var bw: float = BAR_W if not _boss else 56.0
	var x: float = -bw * 0.5
	var y: float = 0.0
	draw_rect(Rect2(x - 1.0, y - 1.0, bw + 2.0, BAR_H + 2.0), Color(0, 0, 0, 0.65))
	var fill: Color = Color(0.239, 0.729, 0.478, 1.0) if not _boss else Color(0.886, 0.333, 0.333, 1.0)
	draw_rect(Rect2(x, y, bw * _ratio, BAR_H), fill)
