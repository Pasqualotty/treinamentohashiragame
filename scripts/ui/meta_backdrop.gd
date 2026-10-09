class_name MetaBackdrop
extends Control
## Fundo vivo das telas-meta (loja, personagens, ajustes, diário, créditos, nome).
## Arte do hub com Ken Burns lento + dim + tint por variante + vinheta radial +
## filete dourado sob o título. Não lê Game nem save: só pinta.
## Nome "BgMeta" começa com "Bg" de propósito — o SafeInset trata como fundo
## (cola na borda em vez de recuar pelo recorte do telefone).

const ART_PATH := "res://assets/ui/hub/bg_still.png"
const KENBURNS_ZOOM := 1.05
const KENBURNS_PERIOD := 20.0
const DIM_ALPHA := 0.62
const LINE_Y := 96.0
const LINE_X := 24.0
const LINE_W := 520.0

## Por variante: tint (cor + alpha), dim extra e se mostra o filete do título.
const VARIANTS := {
	"shop": {"tint": "gold", "tint_a": 0.12, "dim": 0.0, "line": true},
	"characters": {"tint": "water_dim", "tint_a": 0.30, "dim": 0.0, "line": true},
	"settings": {"tint": "none", "tint_a": 0.0, "dim": 0.0, "line": true},
	"diario": {"tint": "crimson", "tint_a": 0.10, "dim": 0.0, "line": true},
	"credits": {"tint": "none", "tint_a": 0.0, "dim": 0.16, "line": true},
	"name": {"tint": "gold", "tint_a": 0.04, "dim": 0.0, "line": false},
}

var variant: String = "settings"
var _art: TextureRect
var _kenburns: Tween


## Cria o fundo e o insere como PRIMEIRO filho de `root` (atrás de tudo).
static func apply(root: Control, variant_name: String) -> MetaBackdrop:
	if root == null:
		return null
	var bd := MetaBackdrop.new()
	bd.name = "BgMeta"
	bd.variant = variant_name if VARIANTS.has(variant_name) else "settings"
	bd.set_anchors_preset(Control.PRESET_FULL_RECT)
	bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bd.clip_contents = true
	root.add_child(bd)
	root.move_child(bd, 0)
	return bd


func _ready() -> void:
	_build()
	_start_kenburns()


func _build() -> void:
	var cfg: Dictionary = VARIANTS[variant]
	add_child(_make_rect("Base", Palette.NIGHT_BG))
	_art = _make_art()
	add_child(_art)
	var tint: Color = _tint_color(str(cfg["tint"]))
	add_child(_make_rect("Tint", Palette.with_alpha(tint, float(cfg["tint_a"]))))
	var dim_a: float = clampf(DIM_ALPHA + float(cfg["dim"]), 0.0, 0.95)
	add_child(_make_rect("Dim", Palette.with_alpha(Palette.INK, dim_a)))
	add_child(_make_vignette())
	if bool(cfg["line"]):
		add_child(_make_line())


func _make_rect(node_name: String, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _make_art() -> TextureRect:
	var art := TextureRect.new()
	art.name = "Art"
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(ART_PATH):
		art.texture = load(ART_PATH) as Texture2D
	art.resized.connect(_center_pivot)
	return art


func _center_pivot() -> void:
	if _art != null:
		_art.pivot_offset = _art.size * 0.5


func _tint_color(key: String) -> Color:
	match key:
		"gold":
			return Palette.GOLD
		"water_dim":
			return Palette.WATER_DIM
		"crimson":
			return Palette.CRIMSON
	return Palette.NIGHT_BG


## Vinheta: centro transparente, bordas escuras (gradiente radial esticado).
func _make_vignette() -> TextureRect:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([
		Palette.with_alpha(Palette.INK, 0.0),
		Palette.with_alpha(Palette.INK, 0.0),
		Palette.with_alpha(Palette.INK, 0.66),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 144
	var rect := TextureRect.new()
	rect.name = "Vignette"
	rect.texture = tex
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Filete dourado fino que some para a direita, sob a área do título.
func _make_line() -> TextureRect:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([
		Palette.with_alpha(Palette.GOLD, 0.7),
		Palette.with_alpha(Palette.GOLD, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.0, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 2
	var line := TextureRect.new()
	line.name = "TitleLine"
	line.texture = tex
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.position = Vector2(LINE_X, LINE_Y)
	line.size = Vector2(LINE_W, 2.0)
	return line


## Ken Burns em ping-pong (mesma ideia do hub): 1.0 → 1.05 → 1.0.
func _start_kenburns() -> void:
	_center_pivot()
	if _kenburns != null and _kenburns.is_valid():
		_kenburns.kill()
	var zoom := Vector2(KENBURNS_ZOOM, KENBURNS_ZOOM)
	_kenburns = create_tween().set_loops()
	_kenburns.tween_property(_art, "scale", zoom, KENBURNS_PERIOD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_kenburns.tween_property(_art, "scale", Vector2.ONE, KENBURNS_PERIOD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
