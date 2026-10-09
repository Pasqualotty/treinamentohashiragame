extends Control
## Mapa do mundo — caminho visual com nós de fase (cleared / locked / boss).
##
## Os nós são gerados em runtime a partir do `WorldCatalog` (StageDefs em
## `resources/stages/`). Não há botão fixo na cena: adicionar uma fase nova ao
## catálogo já faz aparecer o nó, o trecho de caminho e o desbloqueio.

## Espaço de design das posições de nó (`StageDef.map_position`). O canvas real
## é reescalado para caber em qualquer resolução.
const DESIGN_SIZE := Vector2(1280.0, 560.0)

const _Art := preload("res://scripts/world/map_node_art.gd")
const _NodeView := preload("res://scripts/world/map_node_view.gd")
const _Backdrop := preload("res://scripts/world/map_backdrop.gd")
const _TabStyle := preload("res://scripts/world/map_tab_style.gd")

## Entrada dos nós: atraso entre um e outro.
const NODE_STAGGER := 0.07
## Tracejado dourado "fluindo" pelo caminho aberto.
const FLOW_DASH := 14.0
const FLOW_GAP := 12.0
const FLOW_SPEED := 46.0

const BUTTON_SIZE := Vector2(100.0, 100.0)
const BOSS_BUTTON_SIZE := Vector2(110.0, 110.0)

## Estados possíveis de um nó (usados no desenho e no estilo do botão).
const STATE_CLEARED := "cleared"
const STATE_AVAILABLE := "available"
const STATE_BOSS_AVAILABLE := "boss_available"
const STATE_LOCKED := "locked"
const STATE_BOSS_LOCKED := "boss_locked"

## Quantas fases faltantes o status lista antes de resumir com "(+N)".
const MAX_MISSING_SHOWN: int = 2

@onready var status_label: Label = %StatusLabel
@onready var map_canvas: Control = %MapCanvas
@onready var world_tabs: HBoxContainer = %WorldTabs
@onready var title_label: Label = %Title

var _stages: Array[StageDef] = []
## Snapshot do progresso, lido UMA vez por refresh. Rota única de leitura do
## save: nada aqui consulta o autoload direto (ver `WorldCatalog.cleared_ids`).
var _cleared: Array[String] = []
var _stage_buttons: Array[Button] = []
var _node_views: Array[Control] = []
## Fundo em duas camadas (cross-fade entre mundos) + dim + vinheta.
var _art_front: TextureRect
var _art_back: TextureRect
var _art_dim: ColorRect
var _fade_tween: Tween
var _world_buttons: Array[Button] = []
var _world_id: String = WorldCatalog.DEFAULT_WORLD_ID

## Timer ambiente — anima glow do caminho e ring pulsante do próximo nó.
var _t: float = 0.0

## Animação de "viagem" ao confirmar uma fase (spark percorrendo o trecho final).
var _traveling: bool = false
var _travel_target_index: int = 0
var _travel_progress: float = 0.0


func _ready() -> void:
	SafeInset.apply(self)
	_load_catalog()
	map_canvas.set("paint_cb", Callable(self, "_paint_map"))
	_setup_backdrop()
	_build_world_tabs()
	_build_stage_buttons()
	_layout_stage_buttons()
	_refresh_nodes()
	_refresh_world_tabs()
	_apply_world_chrome()
	status_label.text = _intro_text()
	_play_nodes_enter()
	if is_instance_valid(LanSession) and LanSession.is_guest():
		status_label.text = "O anfitrião escolhe a fase"
		for btn: Button in _stage_buttons:
			btn.disabled = true
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
	_cleared = WorldCatalog.cleared_ids()
	var requested: String = WorldCatalog.DEFAULT_WORLD_ID
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var game: Node = (loop as SceneTree).root.get_node_or_null("Game")
		if game != null:
			requested = str(game.get("current_world_id"))
	_world_id = WorldUnlock.clamp_world_id(requested, _cleared)
	_stages = WorldCatalog.load_stages(_world_id)


func _canvas_scale() -> Vector2:
	var size: Vector2 = map_canvas.size if map_canvas.size.x > 1.0 else DESIGN_SIZE
	return Vector2(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)


func _screen_position(index: int) -> Vector2:
	var s: Vector2 = _canvas_scale()
	var p: Vector2 = _stages[index].map_position
	return Vector2(p.x * s.x, p.y * s.y)


func _node_radius(index: int) -> float:
	return _Art.disc_size(_stages[index].is_boss) * 0.5


func _build_world_tabs() -> void:
	for btn: Button in _world_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_world_buttons.clear()
	if world_tabs == null:
		return
	for child: Node in world_tabs.get_children():
		child.queue_free()
	for wid: String in WorldCatalog.world_ids():
		var btn := Button.new()
		btn.name = "WorldTab_%s" % wid
		btn.custom_minimum_size = Vector2(88.0, 36.0)
		btn.clip_text = false
		btn.tooltip_text = WorldCatalog.title_for(wid)
		btn.pressed.connect(_on_world_tab_pressed.bind(wid))
		world_tabs.add_child(btn)
		_world_buttons.append(btn)


func _on_world_tab_pressed(world_id: String) -> void:
	_select_world(world_id)


func _select_world(world_id: String) -> void:
	if _traveling:
		return
	if not WorldUnlock.is_unlocked(world_id, _cleared):
		status_label.text = _world_locked_reason(world_id)
		return
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var game: Node = (loop as SceneTree).root.get_node_or_null("Game")
		if game != null:
			game.set("current_world_id", world_id)
			if game.has_method("save_game"):
				game.call("save_game")
	_world_id = world_id
	_stages = WorldCatalog.load_stages(_world_id)
	_build_stage_buttons()
	_layout_stage_buttons()
	_refresh_nodes()
	_refresh_world_tabs()
	_apply_world_chrome()
	_fade_backdrop()
	status_label.text = _intro_text()
	_play_nodes_enter()


func _world_locked_reason(world_id: String) -> String:
	var req: String = WorldUnlock.required_cleared(world_id)
	var label: String = WorldCatalog.label_for(req) if req != "" and req != "*" else req
	return "%s bloqueado — conclua: %s" % [WorldCatalog.title_for(world_id), label]


func _refresh_world_tabs() -> void:
	for i in range(_world_buttons.size()):
		var btn: Button = _world_buttons[i]
		if not is_instance_valid(btn):
			continue
		var wid: String = WorldCatalog.world_ids()[i] if i < WorldCatalog.world_ids().size() else ""
		if wid == "":
			continue
		var open: bool = WorldUnlock.is_unlocked(wid, _cleared)
		_TabStyle.apply(btn, wid, WorldCatalog.title_for(wid), open, open and wid == _world_id)
		btn.disabled = false


func _apply_world_chrome() -> void:
	if title_label:
		title_label.text = WorldCatalog.title_for(_world_id)
	var overlay := get_node_or_null("Background") as ColorRect
	var accent := get_node_or_null("BgAccent") as ColorRect
	var tint: Color
	match _world_id:
		"w2":
			tint = Color(0.18, 0.12, 0.07, 0.42)
		"w3":
			tint = Color(0.16, 0.08, 0.1, 0.4)
		"w4":
			tint = Color(0.08, 0.08, 0.14, 0.42)
		"w5":
			tint = Color(0.22, 0.05, 0.05, 0.45)
		_:
			tint = Color(0.04, 0.06, 0.05, 0.35)
	if overlay:
		overlay.color = tint
	if accent:
		accent.color = Color(tint.r, tint.g, tint.b, 0.22)


## Camadas do fundo logo acima do MapArt: camada B (cross-fade), dim e vinheta.
func _setup_backdrop() -> void:
	_art_front = get_node_or_null("MapArt") as TextureRect
	if _art_front == null:
		return
	_art_front.texture = _Backdrop.texture_for(_world_id)
	_art_back = _Backdrop.make_back_layer(_art_front)
	_art_dim = _Backdrop.make_dim()
	_art_dim.modulate.a = _Backdrop.dim_for(_world_id)
	var vignette: TextureRect = _Backdrop.make_vignette()
	var at: int = _art_front.get_index() + 1
	for layer: Control in [_art_back, _art_dim, vignette]:
		add_child(layer)
		move_child(layer, at)
		at += 1


func _fade_backdrop() -> void:
	if _art_front == null:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
		_art_front.texture = _art_back.texture
	_fade_tween = _Backdrop.crossfade(self, _art_front, _art_back, _art_dim, _world_id)


## Nós entram em sequência (fade + escala 0.8 -> 1.0).
func _play_nodes_enter() -> void:
	for i in range(_node_views.size()):
		var view: Control = _node_views[i]
		if is_instance_valid(view):
			view.call("play_enter", NODE_STAGGER * float(i))


func _build_stage_buttons() -> void:
	for btn: Button in _stage_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_stage_buttons.clear()
	for view: Control in _node_views:
		if is_instance_valid(view):
			view.queue_free()
	_node_views.clear()
	# Visuais primeiro: os Buttons (área de toque) ficam por cima.
	for i in range(_stages.size()):
		var def: StageDef = _stages[i]
		var view: Control = _NodeView.new()
		view.name = "MapNode_%s" % def.stage_id
		map_canvas.add_child(view)
		view.call("setup", def.is_boss, _chip_text(def), _Art.number_of(def.node_label(), i), "locked")
		_node_views.append(view)
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
		if i < _node_views.size() and is_instance_valid(_node_views[i]):
			_node_views[i].position = _screen_position(i)


# --- Desenho ----------------------------------------------------------------

## Texto do chip: chefe é sempre "Chefe"; as demais usam o rótulo do StageDef.
func _chip_text(def: StageDef) -> String:
	return "Chefe" if def.is_boss else def.node_label()


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
			_draw_ink_flow(canvas, from, to)


## "Tinta fluindo": tracejado dourado que corre de um nó ao seguinte, deslocado por `_t`.
func _draw_ink_flow(canvas: Control, from: Vector2, to: Vector2) -> void:
	var length: float = from.distance_to(to)
	if length < 1.0:
		return
	var dir: Vector2 = (to - from) / length
	var period: float = FLOW_DASH + FLOW_GAP
	var d: float = fmod(_t * FLOW_SPEED, period) - period
	while d < length:
		var a: float = maxf(d, 0.0)
		var b: float = minf(d + FLOW_DASH, length)
		if b > a:
			canvas.draw_line(from + dir * a, from + dir * b, Palette.with_alpha(Palette.GOLD_BRIGHT, 0.95), 3.0, true)
		d += period


## Só o que é animado vive no canvas: o anel pulsante do nó atual e o selo do chefe.
## Medalhão, ícone e rótulo são do MapNodeView.
func _draw_node_rings(canvas: Control) -> void:
	for i in range(_stages.size()):
		var state: String = _node_state(i)
		var center: Vector2 = _screen_position(i)
		var radius: float = _node_radius(i)
		if state == STATE_AVAILABLE or state == STATE_BOSS_AVAILABLE:
			# Ring pulsante — destaca claramente qual é o nó "atual" (próxima fase jogável).
			var pulse: float = sin(_t * 2.6) * 0.5 + 0.5
			var pulse_r: float = radius + 9.0 + pulse * 6.0
			var pulse_a: float = 0.6 - pulse * 0.3
			var pulse_col: Color = Palette.GOLD if state == STATE_AVAILABLE else Palette.CRIMSON_BRIGHT
			canvas.draw_arc(center, pulse_r, 0.0, TAU, 48, Palette.with_alpha(pulse_col, pulse_a), 2.0, true)
		if _stages[i].is_boss and (state == STATE_BOSS_AVAILABLE or state == STATE_CLEARED):
			_draw_boss_seal(canvas, center, radius, state)


func _draw_boss_seal(canvas: Control, center: Vector2, radius: float, state: String) -> void:
	## Selo ceremonial rotativo em torno do nó do boss — raios finos girando devagar.
	var col: Color = Palette.CRIMSON_BRIGHT if state == STATE_BOSS_AVAILABLE else Color(0.6, 0.9, 0.6, 0.9)
	var seal_r: float = radius + 22.0
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
	# Fase concluída vem PRIMEIRO de propósito: quem já venceu nunca perde
	# acesso, mesmo que `requires_cleared` mude depois (save legado).
	if _cleared.has(def.stage_id):
		return STATE_CLEARED
	if not def.is_unlocked(_cleared):
		return STATE_BOSS_LOCKED if def.is_boss else STATE_LOCKED
	return STATE_BOSS_AVAILABLE if def.is_boss else STATE_AVAILABLE


## O jogador pode entrar neste nó?
##
## Derivado de `_node_state` DE PROPÓSITO: se o gate repetisse a condição por
## conta própria ele poderia divergir do que está desenhado — foi exatamente
## esse bug (nó "✓ Boss" que recusava o toque em save legado). Um estado, uma
## regra: o que aparece como acessível é acessível.
func _is_enterable(index: int) -> bool:
	var st: String = _node_state(index)
	return st != STATE_LOCKED and st != STATE_BOSS_LOCKED


func _refresh_nodes() -> void:
	for i in range(_stage_buttons.size()):
		var btn: Button = _stage_buttons[i]
		if not is_instance_valid(btn):
			continue
		var state: String = _node_state(i)
		# Nó bloqueado continua clicável de propósito: `_select_stage` recusa a
		# entrada e explica no status quais fases ainda faltam. Botão `disabled`
		# não emite `pressed` e deixaria o jogador sem nenhuma resposta ao toque.
		# O texto vive no chip do MapNodeView (nunca sobre o ícone); o Button é só toque.
		btn.text = ""
		btn.accessibility_name = _stages[i].node_label()
		if i < _node_views.size() and is_instance_valid(_node_views[i]):
			_node_views[i].call("apply_kind", _kind_of(state))
		_style_stage_button(btn, state)
	if map_canvas:
		map_canvas.queue_redraw()


## Estado do nó -> tipo de medalhão (available | cleared | locked).
func _kind_of(state: String) -> String:
	match state:
		STATE_CLEARED:
			return "cleared"
		STATE_LOCKED, STATE_BOSS_LOCKED:
			return "locked"
	return "available"


## Texto de boas-vindas: aponta o próximo passo em vez de só "escolha uma fase".
func _intro_text() -> String:
	if _stages.is_empty():
		return "Nenhuma fase disponível — catálogo vazio"
	var next: StageDef = WorldCatalog.next_playable(_cleared, _world_id)
	if next == null:
		var nxt_world: String = WorldUnlock.next_world_id(_world_id)
		if nxt_world != "" and WorldUnlock.is_unlocked(nxt_world, _cleared):
			return "Mundo limpo! Próximo: %s" % WorldCatalog.title_for(nxt_world)
		return "Mundo limpo! Rejogue qualquer fase"
	return "Próxima: %s" % next.node_label()


## Motivo legível do bloqueio, citando as fases que faltam.
func _locked_reason(index: int) -> String:
	var def: StageDef = _stages[index]
	var adj: String = "bloqueado" if def.is_boss else "bloqueada"
	var missing: Array[String] = def.missing_requirements(_cleared)
	if missing.is_empty():
		return "%s %s" % [def.node_label(), adj]
	var names := PackedStringArray()
	for req_id: String in missing:
		if names.size() >= MAX_MISSING_SHOWN:
			break
		names.append(WorldCatalog.label_for(req_id, _world_id))
	var listed: String = ", ".join(names)
	var rest: int = missing.size() - names.size()
	if rest > 0:
		listed += " (+%d)" % rest
	return "%s %s — conclua: %s" % [def.node_label(), adj, listed]


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
			# Mesmo tom do antigo `font_disabled_color` — nó bloqueado apagado.
			font_col = Color(0.55, 0.58, 0.6, 0.85)
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", font_col.lightened(0.1))
	btn.add_theme_color_override("font_pressed_color", font_col.darkened(0.1))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.6, 0.85))
	btn.add_theme_font_size_override("font_size", 14)


# --- Ações ------------------------------------------------------------------

func _on_back_pressed() -> void:
	# Durante a viagem já existe uma troca de cena a caminho — não empilhar outra.
	if _traveling:
		return
	SceneRouter.to_hub()


func _on_stage_button_pressed(index: int) -> void:
	_select_stage(index)


func _select_stage(index: int) -> void:
	if index < 0 or index >= _stages.size():
		return
	if _traveling:
		return
	if is_instance_valid(LanSession) and LanSession.is_guest():
		status_label.text = "O anfitrião escolhe a fase"
		return
	var def: StageDef = _stages[index]
	if not _is_enterable(index):
		status_label.text = _locked_reason(index)
		return
	if def.scene_path == "" or not ResourceLoader.exists(def.scene_path):
		push_error("world_map: cena ausente para %s (%s)" % [def.stage_id, def.scene_path])
		status_label.text = "%s indisponível" % def.node_label()
		return
	Game.pending_stage_id = def.stage_id
	status_label.text = "Entrando em %s…" % def.node_label()
	await _play_travel_animation(index)
	# O mapa pode ter saído da árvore durante a animação (ex.: outra navegação).
	if not is_inside_tree():
		return
	if is_instance_valid(LanSession) and LanSession.is_host() and LanSession.has_peer():
		LanSession.announce_stage(def.scene_path)
	SceneRouter.go_to(def.scene_path)


## Flourish curto (spark percorrendo o caminho + bounce no nó) antes de trocar
## de cena — dá a sensação de "viagem" até a fase escolhida.
func _play_travel_animation(index: int) -> void:
	_travel_target_index = index
	_travel_progress = 0.0
	_traveling = true
	var tw: Tween = create_tween()
	tw.tween_method(_set_travel_progress, 0.0, 1.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var view: Control = _node_views[index] if index < _node_views.size() else null
	if is_instance_valid(view):
		view.call("pop")
	await tw.finished
	if is_instance_valid(view):
		view.scale = Vector2.ONE
	_traveling = false
	if map_canvas:
		map_canvas.queue_redraw()


func _set_travel_progress(v: float) -> void:
	_travel_progress = v
