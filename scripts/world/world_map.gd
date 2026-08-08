extends Control
## Mapa do mundo — caminho visual com nós de fase (cleared / locked / boss).
##
## Os nós são gerados em runtime a partir do `WorldCatalog` (StageDefs em
## `resources/stages/`). Não há botão fixo na cena: adicionar uma fase nova ao
## catálogo já faz aparecer o nó, o trecho de caminho e o desbloqueio.

## Espaço de design das posições de nó (`StageDef.map_position`). O canvas real
## é reescalado para caber em qualquer resolução.
const DESIGN_SIZE := Vector2(1280.0, 560.0)

const NODE_RADIUS: float = 42.0
const BOSS_NODE_RADIUS: float = 46.0
const BUTTON_SIZE := Vector2(100.0, 100.0)
const BOSS_BUTTON_SIZE := Vector2(110.0, 110.0)

## Estados possíveis de um nó (usados no desenho e no estilo do botão).
const STATE_CLEARED := "cleared"
const STATE_AVAILABLE := "available"
const STATE_BOSS_AVAILABLE := "boss_available"
const STATE_LOCKED := "locked"
const STATE_BOSS_LOCKED := "boss_locked"

@onready var status_label: Label = %StatusLabel
@onready var map_canvas: Control = %MapCanvas

var _stages: Array[StageDef] = []
## Posições resolvidas (coordenadas de design), 1:1 com `_stages`.
var _node_positions: PackedVector2Array = PackedVector2Array()
var _stage_buttons: Array[Button] = []

## Timer ambiente — anima glow do caminho e ring pulsante do próximo nó.
var _t: float = 0.0

## Animação de "viagem" ao confirmar uma fase (spark percorrendo o trecho final).
var _traveling: bool = false
var _travel_target_index: int = 0
var _travel_progress: float = 0.0


func _ready() -> void:
	_load_catalog()
	map_canvas.set("paint_cb", Callable(self, "_paint_map"))
	_build_stage_buttons()
	_layout_stage_buttons()
	_refresh_nodes()
	status_label.text = _intro_text()
	if is_instance_valid(Audio):
		Audio.play_bgm("hub")


func _process(delta: float) -> void:
	_t += delta
	if map_canvas:
		map_canvas.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and map_canvas:
		_layout_stage_buttons()
		map_canvas.queue_redraw()


# --- Catálogo / nós ---------------------------------------------------------

func _load_catalog() -> void:
	_stages = WorldCatalog.load_stages()
	_node_positions = PackedVector2Array()
	for i in range(_stages.size()):
		_node_positions.append(_resolve_position(i))


## Posição de design do nó `i`. StageDef sem `map_position` cai num serpenteado
## automático — nenhuma fase nova nasce empilhada na origem.
func _resolve_position(index: int) -> Vector2:
	var def: StageDef = _stages[index]
	if def.map_position != Vector2.ZERO:
		return def.map_position
	var count: int = maxi(_stages.size(), 2)
	var t: float = float(index) / float(count - 1)
	var x: float = lerpf(130.0, DESIGN_SIZE.x - 140.0, t)
	var y: float = 470.0 if index % 2 == 0 else 300.0
	return Vector2(x, y)


func _canvas_scale() -> Vector2:
	var size: Vector2 = map_canvas.size if map_canvas.size.x > 1.0 else DESIGN_SIZE
	return Vector2(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)


func _screen_position(index: int) -> Vector2:
	var s: Vector2 = _canvas_scale()
	var p: Vector2 = _node_positions[index]
	return Vector2(p.x * s.x, p.y * s.y)


func _node_radius(index: int) -> float:
	return BOSS_NODE_RADIUS if _stages[index].is_boss else NODE_RADIUS


func _build_stage_buttons() -> void:
	for btn: Button in _stage_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_stage_buttons.clear()
	for i in range(_stages.size()):
		var def: StageDef = _stages[i]
		var btn := Button.new()
		btn.name = "StageButton_%s" % def.stage_id
		btn.flat = true
		btn.clip_text = false
		btn.custom_minimum_size = BOSS_BUTTON_SIZE if def.is_boss else BUTTON_SIZE
		btn.size = btn.custom_minimum_size
		btn.tooltip_text = def.display_name
		btn.pressed.connect(_on_stage_button_pressed.bind(i))
		map_canvas.add_child(btn)
		_stage_buttons.append(btn)


func _layout_stage_buttons() -> void:
	for i in range(_stage_buttons.size()):
		var btn: Button = _stage_buttons[i]
		if not is_instance_valid(btn):
			continue
		btn.size = btn.custom_minimum_size
		btn.position = _screen_position(i) - btn.custom_minimum_size * 0.5


# --- Desenho ----------------------------------------------------------------

func _paint_map(canvas: Control) -> void:
	if _stages.is_empty():
		return
	_draw_path(canvas)
	_draw_node_rings(canvas)
	if _traveling:
		_draw_travel_spark(canvas)


func _draw_path(canvas: Control) -> void:
	var points := PackedVector2Array()
	for i in range(_stages.size()):
		points.append(_screen_position(i))

	for i in range(points.size() - 1):
		canvas.draw_line(points[i], points[i + 1], Color(0.12, 0.1, 0.08, 0.9), 18.0, true)
	for i in range(points.size() - 1):
		canvas.draw_line(points[i], points[i + 1], Color(0.45, 0.38, 0.28, 1.0), 10.0, true)
	for i in range(points.size() - 1):
		var from: Vector2 = points[i]
		var to: Vector2 = points[i + 1]
		var unlocked: bool = _is_path_segment_unlocked(i)
		var col := Palette.with_alpha(Palette.GOLD, 0.95) if unlocked else Color(0.35, 0.38, 0.4, 0.7)
		canvas.draw_line(from, to, col, 3.0, true)
		if unlocked:
			# Glow ambiente pulsando — sugere energia fluindo pelo caminho aberto.
			var glow_a: float = 0.16 + 0.14 * (sin(_t * 2.2 + i * 1.3) * 0.5 + 0.5)
			canvas.draw_line(from, to, Palette.with_alpha(Palette.GOLD_BRIGHT, glow_a), 9.0, true)


func _draw_node_rings(canvas: Control) -> void:
	for i in range(_stages.size()):
		var center: Vector2 = _screen_position(i)
		var radius: float = _node_radius(i)
		var state: String = _node_state(i)
		var fill: Color
		var ring: Color
		match state:
			STATE_CLEARED:
				fill = Color(0.18, 0.42, 0.28, 0.95)
				ring = Color(0.55, 0.9, 0.55, 1.0)
			STATE_AVAILABLE:
				fill = Palette.with_alpha(Palette.GOLD_DIM, 0.95)
				ring = Palette.GOLD
			STATE_BOSS_AVAILABLE:
				fill = Palette.with_alpha(Palette.CRIMSON_DIM, 0.95)
				ring = Palette.CRIMSON_BRIGHT
			_:
				fill = Color(0.2, 0.22, 0.24, 0.9)
				ring = Color(0.45, 0.48, 0.5, 0.85)
		canvas.draw_circle(center, radius + 6.0, Color(0, 0, 0, 0.35))
		canvas.draw_circle(center, radius, fill)
		canvas.draw_arc(center, radius, 0.0, TAU, 48, ring, 4.0, true)
		if state == STATE_LOCKED or state == STATE_BOSS_LOCKED:
			var lock_col := Color(0.75, 0.78, 0.8, 0.95)
			canvas.draw_rect(Rect2(center + Vector2(-10, -2), Vector2(20, 16)), lock_col, true)
			canvas.draw_arc(center + Vector2(0, -4), 8.0, PI, TAU, 16, lock_col, 3.0, true)
		elif state == STATE_CLEARED:
			var a: Vector2 = center + Vector2(-12, 2)
			var b: Vector2 = center + Vector2(-2, 12)
			var c: Vector2 = center + Vector2(14, -10)
			canvas.draw_line(a, b, Color(0.9, 1.0, 0.9, 1.0), 4.0, true)
			canvas.draw_line(b, c, Color(0.9, 1.0, 0.9, 1.0), 4.0, true)
		elif state == STATE_AVAILABLE or state == STATE_BOSS_AVAILABLE:
			# Ring pulsante — destaca claramente qual é o nó "atual" (próxima fase jogável).
			var pulse: float = sin(_t * 2.6) * 0.5 + 0.5
			var pulse_r: float = radius + 9.0 + pulse * 6.0
			var pulse_a: float = 0.6 - pulse * 0.3
			var pulse_col: Color = ring if state == STATE_AVAILABLE else Palette.CRIMSON_BRIGHT
			canvas.draw_arc(center, pulse_r, 0.0, TAU, 48, Palette.with_alpha(pulse_col, pulse_a), 2.0, true)
		if _stages[i].is_boss and (state == STATE_BOSS_AVAILABLE or state == STATE_CLEARED):
			_draw_boss_seal(canvas, center, radius, state)


func _draw_boss_seal(canvas: Control, center: Vector2, radius: float, state: String) -> void:
	## Selo ceremonial rotativo em torno do nó do boss — raios finos girando devagar.
	var col: Color = Palette.CRIMSON_BRIGHT if state == STATE_BOSS_AVAILABLE else Color(0.6, 0.9, 0.6, 0.9)
	var seal_r: float = radius + 16.0
	var rot: float = _t * 0.6
	var spikes: int = 8
	for i in range(spikes):
		var ang: float = rot + TAU * float(i) / float(spikes)
		var dir := Vector2(cos(ang), sin(ang))
		var p1: Vector2 = center + dir * seal_r
		var p2: Vector2 = center + dir * (seal_r + 10.0)
		canvas.draw_line(p1, p2, Palette.with_alpha(col, 0.85), 3.0, true)


func _draw_travel_spark(canvas: Control) -> void:
	if _travel_target_index >= _stages.size():
		return
	var to_s: Vector2 = _screen_position(_travel_target_index)
	var from_s: Vector2 = to_s
	if _travel_target_index > 0:
		from_s = _screen_position(_travel_target_index - 1)
	var p: Vector2 = from_s.lerp(to_s, _travel_progress)
	canvas.draw_circle(p, 16.0, Palette.with_alpha(Palette.GOLD_BRIGHT, 0.30))
	canvas.draw_circle(p, 7.0, Palette.GOLD_BRIGHT)


# --- Estado / progressão ----------------------------------------------------

func _is_path_segment_unlocked(segment_index: int) -> bool:
	var dest: int = segment_index + 1
	if dest >= _stages.size():
		return false
	var st: String = _node_state(dest)
	return st != STATE_LOCKED and st != STATE_BOSS_LOCKED


func _node_state(index: int) -> String:
	var def: StageDef = _stages[index]
	if Game.is_stage_cleared(def.stage_id):
		return STATE_CLEARED
	if not def.is_unlocked():
		return STATE_BOSS_LOCKED if def.is_boss else STATE_LOCKED
	return STATE_BOSS_AVAILABLE if def.is_boss else STATE_AVAILABLE


func _refresh_nodes() -> void:
	for i in range(_stage_buttons.size()):
		var btn: Button = _stage_buttons[i]
		if not is_instance_valid(btn):
			continue
		var state: String = _node_state(i)
		var unlocked: bool = state != STATE_LOCKED and state != STATE_BOSS_LOCKED
		btn.disabled = not unlocked
		var label: String = _stages[i].node_label()
		match state:
			STATE_CLEARED:
				btn.text = "✓\n%s" % label
			STATE_LOCKED, STATE_BOSS_LOCKED:
				btn.text = "🔒\n%s" % label
			_:
				btn.text = label
		_style_stage_button(btn, state)
	if map_canvas:
		map_canvas.queue_redraw()


## Texto de boas-vindas: aponta o próximo passo em vez de só "escolha uma fase".
func _intro_text() -> String:
	if _stages.is_empty():
		return "Nenhuma fase disponível — catálogo vazio"
	var next: StageDef = WorldCatalog.next_playable()
	if next == null:
		return "Mundo 1 — tudo limpo! Rejogue qualquer fase"
	return "Mundo 1 — próxima: %s" % next.node_label()


## Motivo legível do bloqueio, citando as fases que faltam.
func _locked_reason(index: int) -> String:
	var def: StageDef = _stages[index]
	var missing: Array[String] = def.missing_requirements()
	if missing.is_empty():
		return "%s bloqueada" % def.node_label()
	var names := PackedStringArray()
	for req_id: String in missing:
		names.append(WorldCatalog.label_for(req_id))
	return "%s bloqueada — conclua: %s" % [def.node_label(), ", ".join(names)]


func _style_stage_button(btn: Button, state: String) -> void:
	var font_col := Color(0.95, 0.93, 0.88, 1.0)
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.add_theme_stylebox_override("focus", empty)
	match state:
		STATE_CLEARED:
			font_col = Color(0.85, 1.0, 0.85, 1.0)
		STATE_AVAILABLE:
			font_col = Color(1.0, 0.95, 0.7, 1.0)
		STATE_BOSS_AVAILABLE:
			font_col = Color(1.0, 0.75, 0.75, 1.0)
		_:
			font_col = Color(0.65, 0.68, 0.7, 0.9)
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", font_col.lightened(0.1))
	btn.add_theme_color_override("font_pressed_color", font_col.darkened(0.1))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.6, 0.85))
	btn.add_theme_font_size_override("font_size", 14)


# --- Ações ------------------------------------------------------------------

func _on_back_pressed() -> void:
	if is_instance_valid(Audio):
		Audio.play_sfx("ui_click")
	SceneRouter.to_hub()


func _on_stage_button_pressed(index: int) -> void:
	_select_stage(index)


func _select_stage(index: int) -> void:
	if index < 0 or index >= _stages.size():
		return
	if _traveling:
		return
	var def: StageDef = _stages[index]
	if not def.is_unlocked():
		status_label.text = _locked_reason(index)
		return
	if def.scene_path == "" or not ResourceLoader.exists(def.scene_path):
		push_error("world_map: cena ausente para %s (%s)" % [def.stage_id, def.scene_path])
		status_label.text = "%s indisponível" % def.node_label()
		return
	if is_instance_valid(Audio):
		Audio.play_sfx("ui_click")
	Game.pending_stage_id = def.stage_id
	status_label.text = "Entrando em %s…" % def.node_label()
	await _play_travel_animation(index)
	SceneRouter.go_to(def.scene_path)


## Flourish curto (spark percorrendo o caminho + bounce no nó) antes de trocar
## de cena — dá a sensação de "viagem" até a fase escolhida.
func _play_travel_animation(index: int) -> void:
	var btn: Button = _stage_buttons[index] if index < _stage_buttons.size() else null
	_travel_target_index = index
	_travel_progress = 0.0
	_traveling = true
	var tw: Tween = create_tween()
	tw.tween_method(_set_travel_progress, 0.0, 1.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if btn:
		btn.pivot_offset = btn.custom_minimum_size * 0.5
		tw.parallel().tween_property(btn, "scale", Vector2(1.2, 1.2), 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	if is_instance_valid(btn):
		btn.scale = Vector2.ONE
	_traveling = false
	if map_canvas:
		map_canvas.queue_redraw()


func _set_travel_progress(v: float) -> void:
	_travel_progress = v
