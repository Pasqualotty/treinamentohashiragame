extends Area2D
## Portal / goal no fim da fase. Emite `reached` quando o player entra.
## Visual: torii desenhado em código (os ColorRect/Label do .tscn ficam ocultos).
## Trancado = laca dessaturada + corrente/selo + chip "FECHADA"; aberto = laca viva,
## brilho pulsante, partículas douradas e chip "SAÍDA →".

signal reached(body: Node2D)

const SOFT_DOT := "res://assets/backgrounds/w1/layers/soft_dot.tres"
const FONT_BOLD := "res://assets/fonts/NotoSans-Bold.ttf"
const LEGACY_NODES: PackedStringArray = ["PortalGlow", "PortalVisual", "Label"]
const PILLAR_X: float = 44.0
const PILLAR_W: float = 12.0
const HEIGHT: float = 120.0
const MAX_PARTICLES: int = 14

@export var one_shot: bool = true

var _fired: bool = false
var _locked: bool = true
## 0 = trancado, 1 = aberto (anima a troca de cor).
var _open_t: float = 0.0
var _glow: Sprite2D
var _particles: CPUParticles2D
var _chip: Label
var _pulse_tween: Tween
var _open_tween: Tween


func _ready() -> void:
	monitorable = false
	# Player sandbox = layer 2; player move = layer 1 — aceita ambos.
	if collision_mask == 0:
		collision_mask = 1 | 2
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_hide_legacy_nodes()
	_build_glow()
	_build_particles()
	_build_chip()
	# Começa trancado; StageController chama set_locked(false) quando as ondas acabam
	# (ou logo no ready se use_waves=false / lock desligado).
	set_locked(true)


## O chip só aparece quando o centro do torii está dentro da tela; fora disso
## ele vazaria um pedaço cortado na borda.
func _process(_delta: float) -> void:
	if _chip == null:
		return
	var sx: float = get_global_transform_with_canvas().origin.x
	_chip.visible = sx >= 0.0 and sx <= get_viewport().get_visible_rect().size.x


func is_locked() -> bool:
	return _locked


## Trava/destrava o portal (monitoring + visual + pulse).
func set_locked(locked: bool) -> void:
	_locked = locked
	monitoring = not locked
	visible = true
	_apply_state()


func _hide_legacy_nodes() -> void:
	for n: String in LEGACY_NODES:
		var c := get_node_or_null(n) as CanvasItem
		if c != null:
			c.visible = false


## --- Estado ---------------------------------------------------------------

func _apply_state() -> void:
	_kill_tweens()
	_set_chip_text("FECHADA · elimine as ondas" if _locked else "SAÍDA →")
	if _chip != null:
		_chip.modulate = Color(1, 1, 1, 0.9) if _locked else Palette.GOLD_BRIGHT
	if _glow != null:
		_glow.visible = not _locked
	if _particles != null:
		_particles.emitting = not _locked
	_open_tween = create_tween()
	_open_tween.tween_method(_set_open_t, _open_t, 0.0 if _locked else 1.0, 0.35)
	if not _locked:
		_start_pulse()


func _set_open_t(v: float) -> void:
	_open_t = v
	queue_redraw()


func _start_pulse() -> void:
	if _glow == null:
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_glow, "modulate:a", 0.95, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_glow, "modulate:a", 0.45, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _kill_tweens() -> void:
	for t: Tween in [_pulse_tween, _open_tween]:
		if t != null and t.is_valid():
			t.kill()
	_pulse_tween = null
	_open_tween = null


## --- Nós criados em código --------------------------------------------------

func _build_glow() -> void:
	_glow = Sprite2D.new()
	_glow.name = "PortalAura"
	_glow.texture = load(SOFT_DOT) as Texture2D
	_glow.position = Vector2(0, -HEIGHT * 0.5)
	_glow.scale = Vector2(4.4, 4.0) # 64 px * escala ≈ 280 x 256
	_glow.modulate = Color(Palette.GOLD_BRIGHT, 0.7)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.z_index = -1
	add_child(_glow)


func _build_particles() -> void:
	_particles = CPUParticles2D.new()
	_particles.name = "PortalSparks"
	_particles.amount = MAX_PARTICLES
	_particles.lifetime = 1.8
	_particles.texture = load(SOFT_DOT) as Texture2D
	_particles.position = Vector2(0, -8)
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(PILLAR_X - 10.0, 4.0)
	_particles.direction = Vector2(0, -1)
	_particles.spread = 12.0
	_particles.gravity = Vector2.ZERO
	_particles.initial_velocity_min = 34.0
	_particles.initial_velocity_max = 62.0
	_particles.scale_amount_min = 0.06
	_particles.scale_amount_max = 0.12
	_particles.color = Palette.GOLD_BRIGHT
	_particles.emitting = false
	add_child(_particles)


func _build_chip() -> void:
	_chip = Label.new()
	_chip.name = "PortalChip"
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(FONT_BOLD):
		_chip.add_theme_font_override("font", load(FONT_BOLD) as Font)
	_chip.add_theme_font_size_override("font_size", 13)
	_chip.add_theme_color_override("font_color", Palette.CREAM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.with_alpha(Palette.PANEL, 0.85)
	sb.border_color = Palette.with_alpha(Palette.GOLD, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	_chip.add_theme_stylebox_override("normal", sb)
	add_child(_chip)


func _set_chip_text(t: String) -> void:
	if _chip == null:
		return
	_chip.text = t
	var sz: Vector2 = _chip.get_combined_minimum_size()
	_chip.size = sz
	_chip.position = Vector2(-sz.x * 0.5, -HEIGHT - 44.0) # acima do torii: embaixo ficaria sob os botões de toque


## --- Desenho do torii -------------------------------------------------------

func _draw() -> void:
	var lacquer: Color = _tone(Palette.CRIMSON)
	var gold: Color = _tone(Palette.GOLD)
	_draw_pillars(lacquer, gold)
	_draw_beams(lacquer, gold)
	if _open_t < 0.999:
		_draw_chain(1.0 - _open_t)


## Laca dessaturada/escurecida quando trancado, viva quando aberto.
func _tone(c: Color) -> Color:
	var grey := Color(0.36, 0.34, 0.37, 1.0)
	return grey.lerp(c, _open_t)


func _draw_pillars(lacquer: Color, gold: Color) -> void:
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * PILLAR_X
		var outer := Rect2(x - PILLAR_W * 0.5 - 2.0, -HEIGHT, PILLAR_W + 4.0, HEIGHT + 2.0)
		draw_rect(outer, Palette.INK)
		draw_rect(Rect2(x - PILLAR_W * 0.5, -HEIGHT + 2.0, PILLAR_W, HEIGHT - 2.0), lacquer)
		# Friso ouro perto da base + brilho de laca na lateral.
		draw_rect(Rect2(x - PILLAR_W * 0.5, -14.0, PILLAR_W, 4.0), gold)
		draw_rect(Rect2(x - PILLAR_W * 0.5 + 2.0, -HEIGHT + 6.0, 2.0, HEIGHT - 22.0), lacquer.lightened(0.18))


func _draw_beams(lacquer: Color, gold: Color) -> void:
	# Kasagi (viga de cima) com pontas levantadas, e nuki (viga de baixo).
	var top_ink := PackedVector2Array([
		Vector2(-70, -HEIGHT - 12), Vector2(-52, -HEIGHT + 2), Vector2(52, -HEIGHT + 2),
		Vector2(70, -HEIGHT - 12), Vector2(72, -HEIGHT - 2), Vector2(56, -HEIGHT + 16),
		Vector2(-56, -HEIGHT + 16), Vector2(-72, -HEIGHT - 2)])
	draw_colored_polygon(top_ink, Palette.INK)
	var top := PackedVector2Array([
		Vector2(-66, -HEIGHT - 9), Vector2(-50, -HEIGHT + 4), Vector2(50, -HEIGHT + 4),
		Vector2(66, -HEIGHT - 9), Vector2(67, -HEIGHT - 3), Vector2(53, -HEIGHT + 13),
		Vector2(-53, -HEIGHT + 13), Vector2(-67, -HEIGHT - 3)])
	draw_colored_polygon(top, lacquer)
	draw_line(Vector2(-52, -HEIGHT + 5), Vector2(52, -HEIGHT + 5), gold, 2.0)
	draw_rect(Rect2(-PILLAR_X - 6.0, -HEIGHT + 30.0, PILLAR_X * 2.0 + 12.0, 12.0), Palette.INK)
	draw_rect(Rect2(-PILLAR_X - 4.0, -HEIGHT + 32.0, PILLAR_X * 2.0 + 8.0, 8.0), lacquer)


## Corrente em catenária entre os pilares + selo no centro (só trancado).
func _draw_chain(strength: float) -> void:
	var a: float = clampf(strength, 0.0, 1.0)
	var iron := Color(0.62, 0.6, 0.64, a)
	var prev := Vector2(-PILLAR_X, -48.0)
	for i: int in range(1, 9):
		var u: float = float(i) / 8.0
		var p := Vector2(lerpf(-PILLAR_X, PILLAR_X, u), -48.0 + sin(u * PI) * 16.0)
		draw_line(prev, p, iron, 3.0)
		draw_circle(p, 2.6, Color(0.3, 0.29, 0.33, a))
		prev = p
	_draw_seal(Vector2(0, -32.0), a)


func _draw_seal(c: Vector2, a: float) -> void:
	draw_rect(Rect2(c.x - 11.0, c.y - 11.0, 22.0, 22.0), Color(Palette.INK, a))
	draw_rect(Rect2(c.x - 9.0, c.y - 9.0, 18.0, 18.0), Color(Palette.CRIMSON_DIM, a))
	draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), Color(Palette.GOLD, a), 2.0)
	draw_line(c + Vector2(5, -5), c + Vector2(-5, 5), Color(Palette.GOLD, a), 2.0)


func _on_body_entered(body: Node2D) -> void:
	if _locked:
		return
	if _fired and one_shot:
		return
	if body == null or not body.is_in_group("player"):
		return
	_fired = true
	reached.emit(body)
