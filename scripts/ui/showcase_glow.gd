extends Control
## Glow ceremonial sob o personagem no hub — anéis elípticos pulsantes, sombra
## elíptica suave sob os pés e fagulhas douradas subindo devagar.
## Puramente procedural (sem asset novo): anéis e sombra via _draw(), fagulhas via
## CPUParticles2D com uma textura radial gerada em código.

@export var glow_color: Color = Color(0.909804, 0.721569, 0.290196, 1.0)
@export var ring_count: int = 5
@export var pulse_speed: float = 1.1

const SHADOW_LAYERS := 6
const SHADOW_ALPHA := 0.5
## Largura/altura da sombra em relação ao glow (os pés ficam no centro do nó).
const SHADOW_W_RATIO := 0.62
const SHADOW_H_RATIO := 0.46

const SPARK_COUNT := 12
const SPARK_LIFETIME := 7.0
const SPARK_TEX_SIZE := 16

var _t: float = 0.0
var _sparks: CPUParticles2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks = _make_sparks()
	add_child(_sparks)
	resized.connect(_place_sparks)
	_place_sparks()
	set_process(true)
	# O pré-aquecimento só pega depois do layout assentar: reinicia no próximo idle.
	_prewarm_sparks.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var center: Vector2 = size * 0.5
	_draw_shadow(center)
	var pulse: float = sin(_t * pulse_speed) * 0.5 + 0.5
	var rx: float = (size.x * 0.5) * (0.92 + pulse * 0.08)
	var ry: float = (size.y * 0.5) * (0.92 + pulse * 0.08)
	var segs := 40
	for i in range(ring_count, 0, -1):
		var frac: float = float(i) / float(ring_count)
		var a: float = (0.14 * (1.0 - frac)) * (0.7 + pulse * 0.3)
		draw_colored_polygon(_ellipse(center, rx * frac, ry * frac, segs),
			Color(glow_color.r, glow_color.g, glow_color.b, a))


## Sombra de contato: camadas concêntricas de INK, mais opacas no miolo, que somem
## nas bordas — leitura de "pisa no chão" sem borda dura.
func _draw_shadow(center: Vector2) -> void:
	var rx: float = size.x * 0.5 * SHADOW_W_RATIO
	var ry: float = size.y * 0.5 * SHADOW_H_RATIO
	var a: float = SHADOW_ALPHA / float(SHADOW_LAYERS)
	for i in range(SHADOW_LAYERS):
		var frac: float = 1.0 - float(i) / float(SHADOW_LAYERS)
		draw_colored_polygon(_ellipse(center, rx * frac, ry * frac, 32), Palette.with_alpha(Palette.INK, a))


func _ellipse(center: Vector2, rx: float, ry: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for s in range(segs + 1):
		var ang: float = TAU * float(s) / float(segs)
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts


## --- Fagulhas -------------------------------------------------------------

func _make_sparks() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.amount = SPARK_COUNT
	p.lifetime = SPARK_LIFETIME
	# Já começa "no meio do ciclo": sem rajada inicial saindo do chão.
	p.preprocess = SPARK_LIFETIME
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2.UP
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 22.0
	p.initial_velocity_max = 42.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	p.texture = _spark_texture()
	p.color_ramp = _spark_ramp()
	return p


func _prewarm_sparks() -> void:
	if _sparks != null:
		_place_sparks()
		_sparks.emitting = true


func _place_sparks() -> void:
	if _sparks == null:
		return
	_sparks.position = size * 0.5
	_sparks.emission_rect_extents = Vector2(maxf(1.0, size.x * 0.46), 10.0)


## Transparente -> dourado -> transparente ao longo da vida: nasce e some suave.
func _spark_ramp() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	g.colors = PackedColorArray([
		Palette.with_alpha(Palette.GOLD_BRIGHT, 0.0),
		Palette.with_alpha(Palette.GOLD_BRIGHT, 0.85),
		Palette.with_alpha(Palette.GOLD, 0.6),
		Palette.with_alpha(Palette.GOLD, 0.0),
	])
	return g


func _spark_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = SPARK_TEX_SIZE
	t.height = SPARK_TEX_SIZE
	return t
