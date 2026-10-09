extends CanvasLayer
## HUD do mapa de batalha: 4 painéis de caçador (vida com rampa + rastro, respiração),
## chip do cronômetro e tela final. O visual vive em `BrawlHudChrome` / `ModeResultOverlay`.

const HP_GREEN := Color(0.22, 0.82, 0.32, 1.0)
const HP_YELLOW := Color(0.95, 0.82, 0.18, 1.0)
const HP_ORANGE := Color(0.96, 0.48, 0.12, 1.0)
const HP_RED := Color(0.86, 0.16, 0.16, 1.0)
const SIDE_MARGIN: int = 16
const URGENT_SEC: int = 10
const INTRO_SEC: float = 2.0

var _hunters: Array[Node] = []
var _bars: Array[ProgressBar] = []
var _breaths: Array[ProgressBar] = []
var _names: Array[Label] = []
var _hp_texts: Array[Label] = []
var _panels: Array[PanelContainer] = []
var _local_flags: Array[bool] = []
var _time_label: Label
var _time_chip: PanelContainer
var _pulse: Tween
var _urgent: bool = false
var _overlay: ModeResultOverlay
var on_rematch: Callable
var on_leave: Callable


func _ready() -> void:
	layer = 20
	_build()


func bind_hunters(hunters: Array) -> void:
	_hunters.clear()
	for n: Variant in hunters:
		if n is Node:
			_hunters.append(n as Node)
	_refresh()


## Card de abertura, uma vez por partida (não desenha em headless).
func play_intro() -> void:
	var card := CeremonyCard.new()
	card.name = "IntroCard"
	add_child(card)
	card.play("MAPA DE BATALHA", "Até 4 caçadores", "Pads curam, enchem a respiração e dão haste", INTRO_SEC)


func set_time_left(seconds: float) -> void:
	if _time_label == null:
		return
	var s: int = maxi(0, int(ceil(seconds)))
	_time_label.text = "%d:%02d" % [s / 60, s % 60]
	_set_urgent(s < URGENT_SEC)


func show_winner(text: String, subtitle: String = "") -> void:
	if _overlay == null:
		return
	_overlay.set_texts(text, subtitle)
	_overlay.visible = true
	_overlay.play_in()


func has_exit_actions() -> bool:
	return _overlay != null and _overlay.visible


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	var visual_to_slot: Array[int] = [0, 2, 1, 3]
	var i: int = 0
	while i < _bars.size():
		var slot: int = visual_to_slot[i] if i < visual_to_slot.size() else i
		var pawn: Node = _hunters[slot] if slot < _hunters.size() else null
		_apply(pawn, i)
		i += 1


func _apply(pawn: Node, idx: int) -> void:
	if idx >= _bars.size():
		return
	if pawn == null or not is_instance_valid(pawn):
		_panels[idx].visible = false
		return
	_panels[idx].visible = true
	_apply_local(pawn, idx)
	_apply_hp(pawn, idx)
	_apply_breath(pawn, idx)


## Borda ouro mais forte no painel do jogador local (só reestiliza quando muda).
func _apply_local(pawn: Node, idx: int) -> void:
	var local: bool = bool(pawn.get("is_local_pawn"))
	if _local_flags[idx] == local:
		return
	_local_flags[idx] = local
	BrawlHudChrome.style_panel(_panels[idx], local)


func _apply_hp(pawn: Node, idx: int) -> void:
	var cur: int = int(pawn.get("hp"))
	var mx: int = 100
	if pawn.has_method("get_max_hp"):
		mx = maxi(int(pawn.call("get_max_hp")), 1)
	var bar: ProgressBar = _bars[idx]
	bar.max_value = float(mx)
	bar.value = float(maxi(0, cur))
	_paint_hp(bar, float(cur) / float(mx))
	_names[idx].text = _hunter_name(pawn)
	_hp_texts[idx].text = "%d/%d" % [cur, mx]


func _apply_breath(pawn: Node, idx: int) -> void:
	var bcur: float = 0.0
	var bmax: float = 100.0
	if pawn.has_method("get_pawn_breath"):
		bcur = float(pawn.call("get_pawn_breath"))
		bmax = maxf(float(pawn.call("get_pawn_breath_max")), 1.0)
	var breath: ProgressBar = _breaths[idx]
	breath.max_value = bmax
	breath.value = bcur
	var bfill := breath.get_theme_stylebox("fill") as StyleBoxFlat
	if bfill:
		bfill.bg_color = Palette.WATER_BRIGHT if bcur >= bmax else Palette.WATER


## Rampa verde → amarelo → laranja → vermelho (regra de produto, não mexer).
func _paint_hp(bar: ProgressBar, ratio: float) -> void:
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill == null:
		return
	if ratio > 0.66:
		fill.bg_color = HP_GREEN
	elif ratio > 0.4:
		fill.bg_color = HP_YELLOW
	elif ratio > 0.2:
		fill.bg_color = HP_ORANGE
	else:
		fill.bg_color = HP_RED


func _hunter_name(pawn: Node) -> String:
	var id: String = str(pawn.get("applied_character_id"))
	var def: CharacterDef = CharacterCatalog.find(id)
	if def != null and def.display_name != "":
		return def.display_name
	return id.capitalize()


## Cronômetro vermelho e pulsante nos últimos 10 s.
func _set_urgent(urgent: bool) -> void:
	if urgent == _urgent:
		return
	_urgent = urgent
	var tint: Color = Palette.CRIMSON_BRIGHT if urgent else Palette.GOLD
	_time_label.add_theme_color_override("font_color", tint)
	if urgent and (_pulse == null or not _pulse.is_valid()):
		_start_pulse()
	elif not urgent and _pulse != null:
		_pulse.kill()
		_pulse = null
		_time_chip.scale = Vector2.ONE


func _start_pulse() -> void:
	_time_chip.pivot_offset = _time_chip.size * 0.5
	_pulse = _time_chip.create_tween().set_loops()
	_pulse.tween_property(_time_chip, "scale", Vector2(1.08, 1.08), 0.25)
	_pulse.tween_property(_time_chip, "scale", Vector2.ONE, 0.25)


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.add_child(_build_top())
	_overlay = ModeResultOverlay.build("Fim", "", "De novo", _leave_text(), _on_rematch, _on_leave)
	_overlay.visible = false
	root.add_child(_overlay)


func _build_top() -> MarginContainer:
	var pad: Vector4 = SafeInset.viewport_pad(get_viewport())
	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 168.0
	top.add_theme_constant_override("margin_left", maxi(SIDE_MARGIN, int(pad.x)))
	top.add_theme_constant_override("margin_top", 10)
	top.add_theme_constant_override("margin_right", maxi(SIDE_MARGIN, int(pad.z)))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(cols)
	cols.add_child(_build_column(Control.SIZE_SHRINK_BEGIN))
	_time_chip = BrawlHudChrome.make_time_chip()
	_time_label = _time_chip.get_node("TimeLabel") as Label
	cols.add_child(_time_chip)
	cols.add_child(_build_column(Control.SIZE_SHRINK_END))
	return top


## Coluna com 2 painéis, alinhada à esquerda (BEGIN) ou à direita (END).
func _build_column(align: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_fighter_block(col, align)
	_add_fighter_block(col, align)
	return col


func _add_fighter_block(col: VBoxContainer, align: int) -> void:
	var block: Dictionary = BrawlHudChrome.make_block()
	var panel := block["panel"] as PanelContainer
	panel.size_flags_horizontal = align
	panel.visible = false
	col.add_child(panel)
	_panels.append(panel)
	_bars.append(block["hp"] as ProgressBar)
	_breaths.append(block["breath"] as ProgressBar)
	_names.append(block["name"] as Label)
	_hp_texts.append(block["hp_text"] as Label)
	_local_flags.append(false)


func _leave_text() -> String:
	if is_instance_valid(LanSession) and LanSession.in_session():
		return "Lobby"
	return "Sair"


func _on_rematch() -> void:
	if on_rematch.is_valid():
		on_rematch.call()


func _on_leave() -> void:
	if on_leave.is_valid():
		on_leave.call()
