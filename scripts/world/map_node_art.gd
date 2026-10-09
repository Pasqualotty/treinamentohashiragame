extends RefCounted
## Arte dos nós do mapa: textura do medalhão por estado e os ícones desenhados
## (cadeado, check, selo de chefe). Só funções estáticas — quem usa é o MapNodeView
## e o chip de aba trancada (LockGlyph).

const MEDAL_DIR := "res://assets/ui/map"
## Diâmetro do disco visível do medalhão (o PNG tem margem de sombra/espinhos).
const DISC := 84.0
const BOSS_DISC := 96.0
## Fração do lado do PNG ocupada pelo disco (ver tools/gen_map_art.py).
const TEX_DISC_RATIO := 0.88
const TEX_BOSS_RATIO := 0.72


## `kind` é "available" | "cleared" | "locked"; chefe tem arte própria.
static func medal_texture(kind: String, is_boss: bool) -> Texture2D:
	var path: String = "%s/medal_%s%s.png" % [MEDAL_DIR, "boss_" if is_boss else "", kind]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func disc_size(is_boss: bool) -> float:
	return BOSS_DISC if is_boss else DISC


## Lado (em px) do TextureRect que faz o disco visível medir `disc_size`.
static func texture_side(is_boss: bool) -> float:
	return disc_size(is_boss) / (TEX_BOSS_RATIO if is_boss else TEX_DISC_RATIO)


## "Fase 3" -> "3". Sem número no rótulo, cai no índice (1-based) do nó.
static func number_of(label: String, index: int) -> String:
	var digits := ""
	for ch in label:
		if ch >= "0" and ch <= "9":
			digits += ch
	return digits if digits != "" else str(index + 1)


## Cadeado: corpo + argola + furo. `h` = altura total do glifo.
static func draw_lock(ci: CanvasItem, c: Vector2, h: float, col: Color) -> void:
	var shadow := Palette.with_alpha(Palette.INK, 0.55)
	_lock_shape(ci, c + Vector2(0.0, h * 0.04), h, shadow, false)
	_lock_shape(ci, c, h, col, true)


static func _lock_shape(ci: CanvasItem, c: Vector2, h: float, col: Color, keyhole: bool) -> void:
	var body := Rect2(c + Vector2(-0.34, 0.0) * h, Vector2(0.68, 0.46) * h)
	ci.draw_rect(body, col, true)
	ci.draw_arc(c + Vector2(0.0, 0.0), 0.2 * h, PI, TAU, 18, col, maxf(2.0, 0.09 * h), true)
	ci.draw_line(c + Vector2(-0.2, 0.0) * h, c + Vector2(-0.2, 0.05) * h, col, maxf(2.0, 0.09 * h))
	ci.draw_line(c + Vector2(0.2, 0.0) * h, c + Vector2(0.2, 0.05) * h, col, maxf(2.0, 0.09 * h))
	if keyhole:
		var kc: Vector2 = c + Vector2(0.0, 0.2) * h
		ci.draw_circle(kc, 0.06 * h, Palette.with_alpha(Palette.INK, 0.85))
		ci.draw_line(kc, kc + Vector2(0.0, 0.14) * h, Palette.with_alpha(Palette.INK, 0.85), maxf(2.0, 0.06 * h))


## Check de fase concluída (contorno escuro + traço claro).
static func draw_check(ci: CanvasItem, c: Vector2, h: float, col: Color) -> void:
	var a: Vector2 = c + Vector2(-0.34, 0.02) * h
	var b: Vector2 = c + Vector2(-0.1, 0.28) * h
	var d: Vector2 = c + Vector2(0.36, -0.26) * h
	var w: float = maxf(3.0, 0.2 * h)
	var off := Vector2(0.0, 0.05 * h)
	var shadow := Palette.with_alpha(Palette.INK, 0.55)
	ci.draw_polyline(PackedVector2Array([a + off, b + off, d + off]), shadow, w, true)
	ci.draw_polyline(PackedVector2Array([a, b, d]), col, w, true)


## Selo do chefe: losango com miolo — mesma gravura do estandarte do hub.
static func draw_seal(ci: CanvasItem, c: Vector2, h: float, col: Color) -> void:
	var r: float = h * 0.46
	var outer := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r),
		c + Vector2(-r, 0), c + Vector2(0, -r)])
	ci.draw_polyline(outer, col, maxf(3.0, h * 0.12), true)
	var r2: float = r * 0.42
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r2), c + Vector2(r2, 0),
		c + Vector2(0, r2), c + Vector2(-r2, 0)]), col)
