extends Control
## Trilho de XP do hub: fundo escuro, borda de 1 px em ouro 0.45, preenchimento
## dourado com um brilho suave no topo. Só desenha — a regra de XP fica no HunterXp.

const BORDER_ALPHA := 0.45
const FILL_INSET := 2.0
const SHEEN_ALPHA := 0.32

## 0..1; desenha de novo só quando muda.
var ratio: float = 0.0:
	set(value):
		var v: float = clampf(value, 0.0, 1.0)
		if is_equal_approx(v, ratio):
			return
		ratio = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_style_box(_box(Palette.with_alpha(Palette.INK, 0.85), Palette.with_alpha(Palette.GOLD, BORDER_ALPHA), 1, 7),
		Rect2(Vector2.ZERO, size))
	var fill_w: float = (size.x - FILL_INSET * 2.0) * ratio
	if fill_w < 4.0:
		return
	var fill := Rect2(Vector2(FILL_INSET, FILL_INSET), Vector2(fill_w, size.y - FILL_INSET * 2.0))
	draw_style_box(_box(Palette.GOLD, Color(0, 0, 0, 0), 0, 5), fill)
	_draw_sheen(fill)


## Brilho suave: faixa clara na metade de cima do preenchimento.
func _draw_sheen(fill: Rect2) -> void:
	var sheen := Rect2(fill.position + Vector2(2.0, 1.0), Vector2(maxf(0.0, fill.size.x - 4.0), fill.size.y * 0.4))
	draw_style_box(_box(Palette.with_alpha(Palette.CREAM, SHEEN_ALPHA), Color(0, 0, 0, 0), 0, 3), sheen)


func _box(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	return sb
