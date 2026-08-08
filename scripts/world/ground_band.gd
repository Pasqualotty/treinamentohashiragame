@tool
extends Node2D
## Faixa de chão reutilizável das fases.
##
## Desenha a tira de superfície e preenche tudo abaixo dela até `depth`, para
## que o fundo (parallax / arte de céu) NUNCA apareça por baixo da linha do
## chão — era isso que dava a impressão de "piso voando" no meio da tela.
##
## É puramente visual: não cria, não move e não redimensiona colisão. A
## `CollisionShape2D` do `StaticBody2D` pai continua sendo a única fonte de
## verdade da altura de caminhada.
##
## Como usar numa fase nova:
##   1. Instancie `res://scenes/world/ground_band.tscn` como filho do
##      `StaticBody2D` do chão, na origem local (0, 0).
##   2. `band_width` = largura do `RectangleShape2D` do chão. Cobre a extensão
##      inteira da colisão, sem sobrar fundo nas pontas.
##   3. `surface_y`  = y LOCAL do topo da colisão. Para um shape centrado na
##      origem do pai é `-altura / 2` (ex.: shape 2200x48 -> -24).
##   4. `depth`      = quantos pixels descer a partir de `surface_y`. Precisa
##      passar do `limit_bottom` da Camera2D da fase, senão o buraco volta.
##      O default (264) cobre as fases W1 com ~80 px de folga.
##
## O smoke `res://scripts/qa/smoke_facing_ground.gd` valida essa folga em todas
## as fases — se uma fase nova ficar curta, a suíte quebra.

## Margem de erro em pixels: abaixo disso é ruído de float, não geometria.
const EPS: float = 0.5

## Largura total da faixa, centrada na origem local.
@export var band_width: float = 1600.0:
	set(value):
		band_width = maxf(value, 0.0)
		queue_redraw()

## Y local do topo da superfície jogável (topo da colisão do pai).
@export var surface_y: float = -24.0:
	set(value):
		surface_y = value
		queue_redraw()

## Altura total desenhada a partir de `surface_y` para baixo.
@export var depth: float = 264.0:
	set(value):
		depth = maxf(value, 0.0)
		queue_redraw()

## Altura da tira de superfície (o "piso" em si). O resto de `depth` é miolo.
@export var top_height: float = 48.0:
	set(value):
		top_height = maxf(value, 0.0)
		queue_redraw()

## Textura da tira. Repete horizontalmente até cobrir `band_width`.
@export var top_texture: Texture2D:
	set(value):
		top_texture = value
		queue_redraw()

## Fração da textura, do topo pra baixo, que é ignorada ao montar o tile do
## miolo. 0.35 = descarta a linha de superfície, então o preenchimento repete
## só a rocha e não vira uma pilha de pisos.
@export_range(0.0, 0.95, 0.01) var fill_src_ratio: float = 0.35:
	set(value):
		fill_src_ratio = clampf(value, 0.0, 0.95)
		queue_redraw()

## Cor opaca desenhada atrás de tudo. É a rede de segurança contra vazamento
## de fundo: mesmo sem textura, a faixa continua sólida.
@export var fill_color: Color = Color(0.14, 0.11, 0.13):
	set(value):
		fill_color = value
		queue_redraw()

## Multiplicador de cor aplicado ao miolo no ponto mais fundo (dá noção de
## profundidade — o chão escurece conforme desce).
@export var deep_shade: Color = Color(0.42, 0.4, 0.46):
	set(value):
		deep_shade = value
		queue_redraw()


## Y local da base da faixa. Usado pelos smokes pra provar que o chão passa do
## `limit_bottom` da câmera.
func bottom_y() -> float:
	return surface_y + depth


func _draw() -> void:
	if band_width <= EPS or depth <= EPS:
		return

	var half: float = band_width * 0.5
	var top_h: float = clampf(top_height, 0.0, depth)
	var fill_top: float = surface_y + top_h
	var fill_h: float = depth - top_h

	# Base opaca cobrindo a faixa inteira antes de qualquer textura.
	draw_rect(Rect2(-half, surface_y, band_width, depth), fill_color, true)

	if top_texture == null:
		return
	var tex_w: float = float(top_texture.get_width())
	var tex_h: float = float(top_texture.get_height())
	if tex_w <= EPS or tex_h <= EPS:
		return

	# 1) Tira de superfície: a textura inteira, esticada verticalmente pra
	#    `top_h` e repetida na horizontal até fechar `band_width`.
	if top_h > EPS:
		_draw_tiled_row(surface_y, top_h, Rect2(0.0, 0.0, tex_w, tex_h), Color.WHITE)

	if fill_h <= EPS:
		return

	# 2) Miolo: repete só a parte de baixo da textura, escurecendo com a
	#    profundidade. A última linha é recortada (rect e origem da textura
	#    encolhem juntos) pra terminar exatamente em `depth`.
	var src_y: float = tex_h * fill_src_ratio
	var src: Rect2 = Rect2(0.0, src_y, tex_w, tex_h - src_y)
	var vscale: float = (top_h / tex_h) if top_h > EPS else 1.0
	var row_h: float = maxf(src.size.y * vscale, 8.0)
	var fill_bottom: float = fill_top + fill_h
	var y: float = fill_top
	while y < fill_bottom - EPS:
		var h: float = minf(row_h, fill_bottom - y)
		var row_src: Rect2 = Rect2(src.position, Vector2(src.size.x, src.size.y * (h / row_h)))
		var t: float = clampf((y - fill_top) / fill_h, 0.0, 1.0)
		_draw_tiled_row(y, h, row_src, Color.WHITE.lerp(deep_shade, t))
		y += row_h


## Repete `src` horizontalmente de -band_width/2 até +band_width/2, esticando
## cada tile pra altura `h`. A última coluna é recortada na origem da textura
## junto com o rect, pra não distorcer a arte.
func _draw_tiled_row(y: float, h: float, src: Rect2, tint: Color) -> void:
	if top_texture == null or h <= EPS:
		return
	var tile_w: float = src.size.x
	if tile_w <= EPS:
		return
	var half: float = band_width * 0.5
	var x: float = -half
	while x < half - EPS:
		var w: float = minf(tile_w, half - x)
		var col_src: Rect2 = Rect2(
			src.position,
			Vector2(src.size.x * (w / tile_w), src.size.y),
		)
		draw_texture_rect_region(top_texture, Rect2(x, y, w, h), col_src, tint)
		x += tile_w
