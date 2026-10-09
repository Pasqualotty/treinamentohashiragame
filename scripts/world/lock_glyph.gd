extends Control
## Cadeado pequeno desenhado à esquerda de uma aba trancada (filho do Button, sem toque).
## Desenha em coordenadas do pai (origem = canto do chip) e centraliza pela altura dele.

const _Art := preload("res://scripts/world/map_node_art.gd")
const GLYPH_H := 15.0
const LEFT_PAD := 10.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := get_parent() as Control
	if chip != null:
		chip.resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var chip := get_parent() as Control
	var h: float = chip.size.y if chip != null else 38.0
	var c := Vector2(LEFT_PAD + GLYPH_H * 0.45, h * 0.5 - GLYPH_H * 0.2)
	_Art.draw_lock(self, c, GLYPH_H, Palette.with_alpha(Palette.CREAM, 0.7))
