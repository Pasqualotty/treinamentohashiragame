extends CanvasLayer
## HUD de combate — painéis lacados, ícones HP/respiração, moedas, combo.
## Nota: o autoload `Palette`/theme global (Frente B) ainda não está mesclado
## neste branch — cores abaixo aproximam a Style Bible (indigo/painel/carmesim/
## ouro/água/creme) manualmente. Trocar por `Palette.*` quando a Frente B mergear.

@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var breath_bar: ProgressBar = %BreathBar
@onready var breath_label: Label = %BreathLabel
@onready var coins_label: Label = %CoinsLabel
@onready var coins_icon: TextureRect = %CoinsIcon
@onready var combo_block: Control = %ComboBlock
@onready var combo_label: Label = %ComboLabel

const TEX_HEART := "res://assets/ui/icons/hp_heart.png"
const TEX_BREATH := "res://assets/ui/icons/breath_orb.png"
const TEX_COIN := "res://assets/ui/icons/coin.png"

## Style Bible aproximada (ver nota acima).
const COL_PANEL_BG := Color(0.06, 0.05, 0.09, 0.72)
const COL_PANEL_BORDER := Color(0.78, 0.62, 0.22, 0.75)
const COL_GOLD := Color(0.91, 0.74, 0.3, 1.0)
const COL_GOLD_BRIGHT := Color(1.0, 0.85, 0.42, 1.0)
const COL_CREAM := Color(1.0, 0.96, 0.92, 1.0)
const COL_CRIMSON_BRIGHT := Color(0.95, 0.4, 0.32, 1.0)

const COMBO_IDLE_SEC: float = 1.3
const COMBO_POP_MIN: float = 1.22
const COMBO_POP_MAX: float = 1.5

var _hp: float = 100.0
var _hp_max: float = 100.0

var _player_ref: Node = null
var _combo_idle_timer: Timer
var _combo_fade_tween: Tween
var _combo_pop_tween: Tween
var _ult_pulse_tween: Tween


func _ready() -> void:
	_style_chrome()
	_style_bars()
	_style_combo()
	_bind_icons()
	set_hp(_hp, _hp_max)
	_refresh_breath(Game.breath, Game.breath_max)
	_refresh_coins(Game.coins_run)
	if not Game.breath_changed.is_connected(_on_breath_changed):
		Game.breath_changed.connect(_on_breath_changed)
	if not Game.run_coins_changed.is_connected(_on_run_coins_changed):
		Game.run_coins_changed.connect(_on_run_coins_changed)
	_combo_idle_timer = Timer.new()
	_combo_idle_timer.wait_time = COMBO_IDLE_SEC
	_combo_idle_timer.one_shot = true
	_combo_idle_timer.timeout.connect(_on_combo_idle_timeout)
	add_child(_combo_idle_timer)
	set_process(true)
	_try_connect_combo()


func set_hp(current: float, max_value: float) -> void:
	_hp_max = maxf(max_value, 1.0)
	_hp = clampf(current, 0.0, _hp_max)
	hp_bar.max_value = _hp_max
	hp_bar.value = _hp
	hp_label.text = "%d / %d" % [int(round(_hp)), int(round(_hp_max))]


func get_hp() -> float:
	return _hp


func get_hp_max() -> float:
	return _hp_max


func _process(_delta: float) -> void:
	## Conexão defensiva ao combo_changed do player: o player pode não existir
	## ainda no primeiro frame (ordem de instanciação da fase), e o sinal pode
	## nem existir ainda nesta branch (frente H em paralelo). Para de procurar
	## assim que encontra o node do grupo "player" (com ou sem o sinal).
	if _player_ref == null or not is_instance_valid(_player_ref):
		_try_connect_combo()


func _try_connect_combo() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p: Node = players[0]
	_player_ref = p
	if p.has_signal("combo_changed") and not p.is_connected("combo_changed", _on_combo_changed):
		p.connect("combo_changed", _on_combo_changed)
	set_process(false)


func _on_combo_changed(count: int) -> void:
	if count <= 0:
		_fade_combo_out()
		return
	combo_label.text = "x%d COMBO" % count
	combo_label.add_theme_color_override("font_color", _combo_color(count))
	_show_combo(count)
	_combo_idle_timer.start()


func _on_combo_idle_timeout() -> void:
	_fade_combo_out()


func _combo_color(count: int) -> Color:
	if count >= 10:
		return COL_CRIMSON_BRIGHT
	if count >= 5:
		return COL_GOLD_BRIGHT
	return COL_CREAM


func _show_combo(count: int) -> void:
	if _combo_fade_tween and _combo_fade_tween.is_valid():
		_combo_fade_tween.kill()
	_combo_fade_tween = create_tween()
	_combo_fade_tween.tween_property(combo_block, "modulate:a", 1.0, 0.06)

	if _combo_pop_tween and _combo_pop_tween.is_valid():
		_combo_pop_tween.kill()
	var pop: float = lerpf(COMBO_POP_MIN, COMBO_POP_MAX, clampf(float(count) / 20.0, 0.0, 1.0))
	combo_block.scale = Vector2(pop, pop)
	_combo_pop_tween = create_tween()
	_combo_pop_tween.set_trans(Tween.TRANS_BACK)
	_combo_pop_tween.set_ease(Tween.EASE_OUT)
	_combo_pop_tween.tween_property(combo_block, "scale", Vector2.ONE, 0.22)


func _fade_combo_out() -> void:
	if _combo_fade_tween and _combo_fade_tween.is_valid():
		_combo_fade_tween.kill()
	_combo_fade_tween = create_tween()
	_combo_fade_tween.tween_property(combo_block, "modulate:a", 0.0, 0.45)


func _on_breath_changed(value: float, max_value: float) -> void:
	_refresh_breath(value, max_value)


func _on_run_coins_changed(run_total: int) -> void:
	_refresh_coins(run_total)


func _refresh_breath(value: float, max_value: float) -> void:
	var m: float = maxf(max_value, 1.0)
	breath_bar.max_value = m
	breath_bar.value = clampf(value, 0.0, m)
	var is_full: bool = value >= m
	breath_label.text = "ULT!" if is_full else "%d%%" % int(round(value / m * 100.0))
	if is_full:
		breath_bar.modulate = Color(1.2, 1.15, 0.95, 1.0)
		_start_ultimate_flourish()
	else:
		breath_bar.modulate = Color.WHITE
		_stop_ultimate_flourish()


func _start_ultimate_flourish() -> void:
	if _ult_pulse_tween and _ult_pulse_tween.is_valid():
		return
	var icon := get_node_or_null("%BreathIcon") as CanvasItem
	if icon == null:
		return
	_ult_pulse_tween = create_tween()
	_ult_pulse_tween.set_loops()
	_ult_pulse_tween.set_trans(Tween.TRANS_SINE)
	_ult_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	_ult_pulse_tween.tween_property(icon, "scale", Vector2(1.22, 1.22), 0.42)
	_ult_pulse_tween.parallel().tween_property(icon, "modulate", Color(1.35, 1.08, 0.5, 1.0), 0.42)
	_ult_pulse_tween.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.42)
	_ult_pulse_tween.parallel().tween_property(icon, "modulate", Color(1, 1, 1, 1), 0.42)


func _stop_ultimate_flourish() -> void:
	if _ult_pulse_tween and _ult_pulse_tween.is_valid():
		_ult_pulse_tween.kill()
	_ult_pulse_tween = null
	var icon := get_node_or_null("%BreathIcon") as CanvasItem
	if icon:
		icon.set("scale", Vector2.ONE)
		icon.set("modulate", Color(1, 1, 1, 1))


func _refresh_coins(run_total: int) -> void:
	coins_label.text = str(run_total)


func _bind_icons() -> void:
	var hp_icon := get_node_or_null("%HpIcon") as CanvasItem
	if hp_icon == null:
		hp_icon = find_child("HpIcon", true, false) as CanvasItem
	_set_icon_texture(hp_icon, TEX_HEART)
	var br_icon := get_node_or_null("%BreathIcon") as CanvasItem
	if br_icon == null:
		br_icon = find_child("BreathIcon", true, false) as CanvasItem
	_set_icon_texture(br_icon, TEX_BREATH)
	if br_icon is TextureRect:
		# Pivot centrado — necessário pro pulse de ultimate escalar sem deslocar.
		var trect: TextureRect = br_icon as TextureRect
		trect.pivot_offset = trect.custom_minimum_size * 0.5
	if coins_icon and ResourceLoader.exists(TEX_COIN):
		coins_icon.texture = load(TEX_COIN) as Texture2D


func _set_icon_texture(node: CanvasItem, path: String) -> void:
	if node == null or not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path) as Texture2D
	if node is TextureRect:
		(node as TextureRect).texture = tex
		(node as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		(node as TextureRect).stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	elif node is Sprite2D:
		(node as Sprite2D).texture = tex


func _style_chrome() -> void:
	# Painéis lacados atrás de HP/Respiração/Moedas (PanelContainer — precisa
	# ser um tipo que realmente desenha "panel", Box/VBox não desenham).
	for path: String in ["HpBlock", "BreathBlock", "CoinsBlock"]:
		var block := find_child(path, true, false) as Control
		if block == null:
			continue
		block.add_theme_stylebox_override("panel", _make_panel_style(COL_PANEL_BORDER, COL_PANEL_BG))


func _style_combo() -> void:
	combo_block.modulate = Color(1, 1, 1, 0)
	# Pivot centrado — o pop de escala precisa crescer a partir do centro,
	# não do canto superior esquerdo (default do Control).
	combo_block.pivot_offset = combo_block.size * 0.5
	var panel := find_child("ComboPanel", true, false) as Control
	if panel:
		panel.add_theme_stylebox_override(
			"panel", _make_panel_style(COL_GOLD, Color(0.08, 0.05, 0.04, 0.8))
		)
	combo_label.add_theme_font_size_override("font_size", 26)
	combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	combo_label.add_theme_constant_override("outline_size", 3)


func _make_panel_style(border: Color, bg: Color) -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = bg
	panel.border_color = border
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(10)
	panel.content_margin_left = 10
	panel.content_margin_right = 10
	panel.content_margin_top = 6
	panel.content_margin_bottom = 8
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 4
	return panel


func _style_bars() -> void:
	_apply_bar_style(
		hp_bar,
		Color(0.12, 0.06, 0.08, 0.95),
		Color(0.88, 0.2, 0.24, 1.0),
		Color(0.95, 0.45, 0.35, 1.0)
	)
	_apply_bar_style(
		breath_bar,
		Color(0.06, 0.08, 0.16, 0.95),
		Color(0.35, 0.55, 0.95, 1.0),
		Color(0.55, 0.8, 1.0, 1.0)
	)
	for lbl: Label in [hp_label, breath_label, coins_label]:
		if lbl == null:
			continue
		lbl.add_theme_font_size_override("font_size", 20 if lbl != coins_label else 26)
		lbl.add_theme_color_override("font_color", COL_CREAM)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		lbl.add_theme_constant_override("outline_size", 3)


func _apply_bar_style(bar: ProgressBar, bg: Color, fill: Color, fill_hi: Color) -> void:
	if bar == null:
		return
	var bg_box := StyleBoxFlat.new()
	bg_box.bg_color = bg
	bg_box.border_color = Color(0.55, 0.45, 0.2, 0.65)
	bg_box.set_border_width_all(1)
	bg_box.set_corner_radius_all(8)
	bg_box.content_margin_left = 3
	bg_box.content_margin_top = 3
	bg_box.content_margin_right = 3
	bg_box.content_margin_bottom = 3
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = fill
	fill_box.set_corner_radius_all(6)
	# Gradiente fake: cor principal (Godot StyleBoxFlat só 1 cor — usa fill)
	bar.add_theme_stylebox_override("background", bg_box)
	bar.add_theme_stylebox_override("fill", fill_box)
	bar.custom_minimum_size.y = 26
	bar.show_percentage = false
	bar.modulate = Color(1, 1, 1, 1)
