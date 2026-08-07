extends Control
## Mapa do mundo W1 — caminho visual com nós de fase (cleared / locked / boss).

## IDs canônicos (save / StageController).
const STAGE_IDS: Array[String] = ["w1_01", "w1_02", "w1_03", "w1_boss"]
const STAGE_SCENES: Array[String] = [
	"res://scenes/battle/stage_w1_01.tscn",
	"res://scenes/battle/stage_w1_02.tscn",
	"res://scenes/battle/stage_w1_03.tscn",
	"res://scenes/battle/stage_w1_boss.tscn",
]
const STAGE_LABELS: Array[String] = ["Fase 1", "Fase 2", "Fase 3", "Boss"]
## Posições dos nós no mapa (design 1280×720, área do canvas ~560h).
const NODE_POSITIONS: Array[Vector2] = [
	Vector2(200, 460),
	Vector2(420, 300),
	Vector2(700, 420),
	Vector2(980, 260),
]
const NODE_RADIUS: float = 42.0

@onready var status_label: Label = %StatusLabel
@onready var map_canvas: Control = %MapCanvas
@onready var stage1_btn: Button = %Stage1Button
@onready var stage2_btn: Button = %Stage2Button
@onready var stage3_btn: Button = %Stage3Button
@onready var boss_btn: Button = %BossButton

var _stage_buttons: Array[Button] = []

## Timer ambiente — anima glow do caminho e ring pulsante do próximo nó.
var _t: float = 0.0

## Animação de "viagem" ao confirmar uma fase (spark percorrendo o trecho final).
var _traveling: bool = false
var _travel_target_index: int = 0
var _travel_progress: float = 0.0


func _ready() -> void:
	_stage_buttons = [stage1_btn, stage2_btn, stage3_btn, boss_btn]
	map_canvas.set("paint_cb", Callable(self, "_paint_map"))
	_layout_stage_buttons()
	_refresh_nodes()
	status_label.text = "Mundo 1 — escolha uma fase no caminho"
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


func _layout_stage_buttons() -> void:
	var size: Vector2 = map_canvas.size if map_canvas.size.x > 1.0 else Vector2(1280, 560)
	var scale_x: float = size.x / 1280.0
	var scale_y: float = size.y / 560.0
	for i in range(_stage_buttons.size()):
		var btn: Button = _stage_buttons[i]
		if btn == null:
			continue
		var p: Vector2 = NODE_POSITIONS[i]
		var pos := Vector2(p.x * scale_x, p.y * scale_y)
		btn.position = pos - btn.custom_minimum_size * 0.5
		btn.size = btn.custom_minimum_size


func _paint_map(canvas: Control) -> void:
	_draw_path(canvas)
	_draw_node_rings(canvas)
	if _traveling:
		_draw_travel_spark(canvas)


func _draw_path(canvas: Control) -> void:
	var size: Vector2 = canvas.size if canvas.size.x > 1.0 else Vector2(1280, 560)
	var scale_x: float = size.x / 1280.0
	var scale_y: float = size.y / 560.0
	var points: PackedVector2Array = PackedVector2Array()
	for p in NODE_POSITIONS:
		points.append(Vector2(p.x * scale_x, p.y * scale_y))

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
	var size: Vector2 = canvas.size if canvas.size.x > 1.0 else Vector2(1280, 560)
	var scale_x: float = size.x / 1280.0
	var scale_y: float = size.y / 560.0
	for i in range(NODE_POSITIONS.size()):
		var center := Vector2(NODE_POSITIONS[i].x * scale_x, NODE_POSITIONS[i].y * scale_y)
		var state: String = _node_state(i)
		var fill: Color
		var ring: Color
		match state:
			"cleared":
				fill = Color(0.18, 0.42, 0.28, 0.95)
				ring = Color(0.55, 0.9, 0.55, 1.0)
			"available":
				fill = Palette.with_alpha(Palette.GOLD_DIM, 0.95)
				ring = Palette.GOLD
			"boss_available":
				fill = Palette.with_alpha(Palette.CRIMSON_DIM, 0.95)
				ring = Palette.CRIMSON_BRIGHT
			_:
				fill = Color(0.2, 0.22, 0.24, 0.9)
				ring = Color(0.45, 0.48, 0.5, 0.85)
		canvas.draw_circle(center, NODE_RADIUS + 6.0, Color(0, 0, 0, 0.35))
		canvas.draw_circle(center, NODE_RADIUS, fill)
		canvas.draw_arc(center, NODE_RADIUS, 0.0, TAU, 48, ring, 4.0, true)
		if state == "locked" or state == "boss_locked":
			var lock_col := Color(0.75, 0.78, 0.8, 0.95)
			canvas.draw_rect(Rect2(center + Vector2(-10, -2), Vector2(20, 16)), lock_col, true)
			canvas.draw_arc(center + Vector2(0, -4), 8.0, PI, TAU, 16, lock_col, 3.0, true)
		elif state == "cleared":
			var a: Vector2 = center + Vector2(-12, 2)
			var b: Vector2 = center + Vector2(-2, 12)
			var c: Vector2 = center + Vector2(14, -10)
			canvas.draw_line(a, b, Color(0.9, 1.0, 0.9, 1.0), 4.0, true)
			canvas.draw_line(b, c, Color(0.9, 1.0, 0.9, 1.0), 4.0, true)
		elif state == "available" or state == "boss_available":
			# Ring pulsante — destaca claramente qual é o nó "atual" (próxima fase jogável).
			var pulse: float = sin(_t * 2.6) * 0.5 + 0.5
			var pulse_r: float = NODE_RADIUS + 9.0 + pulse * 6.0
			var pulse_a: float = 0.6 - pulse * 0.3
			var pulse_col: Color = ring if state == "available" else Palette.CRIMSON_BRIGHT
			canvas.draw_arc(center, pulse_r, 0.0, TAU, 48, Palette.with_alpha(pulse_col, pulse_a), 2.0, true)
		if i == 3 and (state == "boss_available" or state == "cleared"):
			_draw_boss_seal(canvas, center, state)


func _draw_boss_seal(canvas: Control, center: Vector2, state: String) -> void:
	## Selo ceremonial rotativo em torno do nó do boss — raios finos girando devagar.
	var col: Color = Palette.CRIMSON_BRIGHT if state == "boss_available" else Color(0.6, 0.9, 0.6, 0.9)
	var seal_r: float = NODE_RADIUS + 16.0
	var rot: float = _t * 0.6
	var spikes: int = 8
	for i in range(spikes):
		var ang: float = rot + TAU * float(i) / float(spikes)
		var dir := Vector2(cos(ang), sin(ang))
		var p1: Vector2 = center + dir * seal_r
		var p2: Vector2 = center + dir * (seal_r + 10.0)
		canvas.draw_line(p1, p2, Palette.with_alpha(col, 0.85), 3.0, true)


func _draw_travel_spark(canvas: Control) -> void:
	var size: Vector2 = canvas.size if canvas.size.x > 1.0 else Vector2(1280, 560)
	var scale_x: float = size.x / 1280.0
	var scale_y: float = size.y / 560.0
	var to_pos: Vector2 = NODE_POSITIONS[_travel_target_index]
	var from_pos: Vector2 = to_pos
	if _travel_target_index > 0:
		from_pos = NODE_POSITIONS[_travel_target_index - 1]
	var from_s := Vector2(from_pos.x * scale_x, from_pos.y * scale_y)
	var to_s := Vector2(to_pos.x * scale_x, to_pos.y * scale_y)
	var p: Vector2 = from_s.lerp(to_s, _travel_progress)
	canvas.draw_circle(p, 16.0, Palette.with_alpha(Palette.GOLD_BRIGHT, 0.30))
	canvas.draw_circle(p, 7.0, Palette.GOLD_BRIGHT)


func _is_path_segment_unlocked(segment_index: int) -> bool:
	var dest: int = segment_index + 1
	var st: String = _node_state(dest)
	return st != "locked" and st != "boss_locked"


func _node_state(index: int) -> String:
	var stage_id: String = STAGE_IDS[index]
	if Game.is_stage_cleared(stage_id):
		return "cleared"
	if not _is_stage_unlocked(index):
		return "boss_locked" if index == 3 else "locked"
	if index == 3:
		return "boss_available"
	return "available"


func _is_stage_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	if index == 3:
		return (
			Game.is_stage_cleared(STAGE_IDS[0])
			and Game.is_stage_cleared(STAGE_IDS[1])
			and Game.is_stage_cleared(STAGE_IDS[2])
		)
	return Game.is_stage_cleared(STAGE_IDS[index - 1])


func _refresh_nodes() -> void:
	for i in range(_stage_buttons.size()):
		var btn: Button = _stage_buttons[i]
		if btn == null:
			continue
		var state: String = _node_state(i)
		var unlocked: bool = state != "locked" and state != "boss_locked"
		btn.disabled = not unlocked
		var label: String = STAGE_LABELS[i]
		match state:
			"cleared":
				btn.text = "✓\n%s" % label
			"locked", "boss_locked":
				btn.text = "🔒\n%s" % label
			_:
				btn.text = label
		_style_stage_button(btn, state)
	if map_canvas:
		map_canvas.queue_redraw()


func _style_stage_button(btn: Button, state: String) -> void:
	var font_col := Color(0.95, 0.93, 0.88, 1.0)
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.add_theme_stylebox_override("focus", empty)
	match state:
		"cleared":
			font_col = Color(0.85, 1.0, 0.85, 1.0)
		"available":
			font_col = Color(1.0, 0.95, 0.7, 1.0)
		"boss_available":
			font_col = Color(1.0, 0.75, 0.75, 1.0)
		_:
			font_col = Color(0.65, 0.68, 0.7, 0.9)
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", font_col.lightened(0.1))
	btn.add_theme_color_override("font_pressed_color", font_col.darkened(0.1))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.6, 0.85))
	btn.add_theme_font_size_override("font_size", 14)


func _on_back_pressed() -> void:
	if is_instance_valid(Audio):
		Audio.play_sfx("ui_click")
	SceneRouter.to_hub()


func _on_stage_1_pressed() -> void:
	_select_stage(0)


func _on_stage_2_pressed() -> void:
	_select_stage(1)


func _on_stage_3_pressed() -> void:
	_select_stage(2)


func _on_boss_pressed() -> void:
	_select_stage(3)


func _select_stage(index: int) -> void:
	if not _is_stage_unlocked(index):
		if index == 3:
			status_label.text = "Boss bloqueado — limpe as 3 fases"
		else:
			status_label.text = "%s bloqueada — complete a fase anterior" % STAGE_LABELS[index]
		return
	if is_instance_valid(Audio):
		Audio.play_sfx("ui_click")
	var stage_id: String = STAGE_IDS[index]
	var scene_path: String = STAGE_SCENES[index]
	Game.pending_stage_id = stage_id
	status_label.text = "Entrando em %s…" % STAGE_LABELS[index]
	await _play_travel_animation(index)
	SceneRouter.go_to(scene_path)


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
	if btn:
		btn.scale = Vector2.ONE
	_traveling = false
	if map_canvas:
		map_canvas.queue_redraw()


func _set_travel_progress(v: float) -> void:
	_travel_progress = v
