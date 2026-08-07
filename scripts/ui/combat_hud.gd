extends CanvasLayer
## HUD de combate — painéis lacados, ícones HP/respiração, moedas.
## HP anima suave ao mudar (tween) e pulsa em vermelho quando baixo (<25%).
## Respiração ganha brilho pulsante quando cheia (ULT pronta).
## Moedas dão um "pop" de escala a cada mudança.

@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var breath_bar: ProgressBar = %BreathBar
@onready var breath_label: Label = %BreathLabel
@onready var coins_label: Label = %CoinsLabel
@onready var coins_icon: TextureRect = %CoinsIcon

const TEX_HEART := "res://assets/ui/icons/hp_heart.png"
const TEX_BREATH := "res://assets/ui/icons/breath_orb.png"
const TEX_COIN := "res://assets/ui/icons/coin.png"

const LOW_HP_RATIO := 0.25
const HP_TWEEN_DURATION := 0.35
const BREATH_TWEEN_DURATION := 0.3
const POP_DURATION := 0.12
const POP_SCALE := 1.28
const PULSE_PERIOD := 0.55

var _hp: float = 100.0
var _hp_max: float = 100.0
var _breath_full: bool = false
var _low_hp: bool = false
var _last_coins: int = 0

var _hp_block: Control
var _breath_block: Control
var _coins_block: Control

var _hp_value_tween: Tween
var _breath_value_tween: Tween
var _low_hp_tween: Tween
var _breath_glow_tween: Tween


func _ready() -> void:
	_hp_block = find_child("HpBlock", true, false) as Control
	_breath_block = find_child("BreathBlock", true, false) as Control
	_coins_block = find_child("CoinsBlock", true, false) as Control

	_style_chrome()
	_style_bars()
	_bind_icons()
	set_hp(_hp, _hp_max)
	_refresh_breath(Game.breath, Game.breath_max)
	_last_coins = Game.coins_run
	_refresh_coins(Game.coins_run, false)
	if not Game.breath_changed.is_connected(_on_breath_changed):
		Game.breath_changed.connect(_on_breath_changed)
	if not Game.run_coins_changed.is_connected(_on_run_coins_changed):
		Game.run_coins_changed.connect(_on_run_coins_changed)
	# Pivot central p/ o "pop" de moedas escalar a partir do meio, não do canto.
	await get_tree().process_frame
	_center_pivot(coins_icon)
	_center_pivot(coins_label)


## --- API pública (mantida) -------------------------------------------

func set_hp(current: float, max_value: float) -> void:
	_hp_max = maxf(max_value, 1.0)
	_hp = clampf(current, 0.0, _hp_max)
	hp_label.text = "%d / %d" % [int(round(_hp)), int(round(_hp_max))]
	hp_bar.max_value = _hp_max
	_animate_hp_bar()
	_refresh_low_hp_state()


func get_hp() -> float:
	return _hp


func get_hp_max() -> float:
	return _hp_max


## --- Sinais -------------------------------------------------------------

func _on_breath_changed(value: float, max_value: float) -> void:
	_refresh_breath(value, max_value)


func _on_run_coins_changed(run_total: int) -> void:
	_refresh_coins(run_total, true)


## --- HP: tween + pulse baixo ---------------------------------------------

func _animate_hp_bar() -> void:
	if _hp_value_tween and _hp_value_tween.is_valid():
		_hp_value_tween.kill()
	_hp_value_tween = create_tween()
	_hp_value_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hp_value_tween.tween_property(hp_bar, "value", _hp, HP_TWEEN_DURATION)


func _refresh_low_hp_state() -> void:
	var ratio: float = _hp / _hp_max if _hp_max > 0.0 else 0.0
	var should_pulse: bool = ratio < LOW_HP_RATIO and _hp > 0.0
	if should_pulse == _low_hp:
		return
	_low_hp = should_pulse
	if _low_hp:
		_start_low_hp_pulse()
	else:
		_stop_low_hp_pulse()


func _start_low_hp_pulse() -> void:
	if _hp_block == null:
		return
	if _low_hp_tween and _low_hp_tween.is_valid():
		_low_hp_tween.kill()
	_hp_block.self_modulate = Color(1, 1, 1, 1)
	_low_hp_tween = create_tween()
	_low_hp_tween.set_loops()
	_low_hp_tween.tween_property(_hp_block, "self_modulate", Palette.CRIMSON_BRIGHT, PULSE_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_low_hp_tween.tween_property(_hp_block, "self_modulate", Color(1, 1, 1, 1), PULSE_PERIOD * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_low_hp_pulse() -> void:
	if _low_hp_tween and _low_hp_tween.is_valid():
		_low_hp_tween.kill()
	if _hp_block:
		_hp_block.self_modulate = Color(1, 1, 1, 1)


## --- Respiração: fill tween + glow quando cheia -------------------------

func _refresh_breath(value: float, max_value: float) -> void:
	var m: float = maxf(max_value, 1.0)
	breath_bar.max_value = m
	var target: float = clampf(value, 0.0, m)
	if _breath_value_tween and _breath_value_tween.is_valid():
		_breath_value_tween.kill()
	_breath_value_tween = create_tween()
	_breath_value_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_breath_value_tween.tween_property(breath_bar, "value", target, BREATH_TWEEN_DURATION)

	var is_full: bool = value >= m
	breath_label.text = "ULT!" if is_full else "%d%%" % int(round(value / m * 100.0))
	if is_full == _breath_full:
		return
	_breath_full = is_full
	if _breath_full:
		_start_breath_glow()
	else:
		_stop_breath_glow()


func _start_breath_glow() -> void:
	if _breath_block == null:
		return
	if _breath_glow_tween and _breath_glow_tween.is_valid():
		_breath_glow_tween.kill()
	breath_bar.modulate = Color(1.2, 1.15, 0.95, 1.0)
	_breath_glow_tween = create_tween()
	_breath_glow_tween.set_loops()
	_breath_glow_tween.tween_property(_breath_block, "self_modulate", Palette.WATER_BRIGHT, PULSE_PERIOD * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath_glow_tween.tween_property(_breath_block, "self_modulate", Color(1, 1, 1, 1), PULSE_PERIOD * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_breath_glow() -> void:
	if _breath_glow_tween and _breath_glow_tween.is_valid():
		_breath_glow_tween.kill()
	if _breath_block:
		_breath_block.self_modulate = Color(1, 1, 1, 1)
	breath_bar.modulate = Color.WHITE


## --- Moedas: pop de escala ao mudar --------------------------------------

func _refresh_coins(run_total: int, animate: bool) -> void:
	coins_label.text = str(run_total)
	if animate and run_total != _last_coins:
		_pop(coins_icon)
		_pop(coins_label)
	_last_coins = run_total


func _pop(node: Control) -> void:
	if node == null:
		return
	var prev: Variant = node.get_meta("_pop_tween", null)
	if prev is Tween and (prev as Tween).is_valid():
		(prev as Tween).kill()
	_center_pivot(node)
	node.scale = Vector2.ONE
	var tw: Tween = create_tween()
	node.set_meta("_pop_tween", tw)
	tw.tween_property(node, "scale", Vector2(POP_SCALE, POP_SCALE), POP_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, POP_DURATION * 1.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _center_pivot(node: Control) -> void:
	if node == null:
		return
	node.pivot_offset = node.size * 0.5


## --- Ícones ----------------------------------------------------------

func _bind_icons() -> void:
	var hp_icon := get_node_or_null("%HpIcon") as CanvasItem
	if hp_icon == null:
		hp_icon = find_child("HpIcon", true, false) as CanvasItem
	_set_icon_texture(hp_icon, TEX_HEART)
	var br_icon := get_node_or_null("%BreathIcon") as CanvasItem
	if br_icon == null:
		br_icon = find_child("BreathIcon", true, false) as CanvasItem
	_set_icon_texture(br_icon, TEX_BREATH)
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


## --- Estilo / paleta ----------------------------------------------------

func _style_chrome() -> void:
	# Painéis escuros atrás das barras (blocos agora são PanelContainer —
	# a stylebox "panel" é realmente desenhada, ao contrário do antigo Box).
	for path: String in ["HpBlock", "BreathBlock", "CoinsBlock"]:
		var block := find_child(path, true, false) as Control
		if block == null:
			continue
		var panel := StyleBoxFlat.new()
		panel.bg_color = Palette.with_alpha(Palette.PANEL, 0.78)
		panel.border_color = Palette.with_alpha(Palette.GOLD, 0.6)
		panel.set_border_width_all(2)
		panel.set_corner_radius_all(10)
		panel.content_margin_left = 10
		panel.content_margin_right = 10
		panel.content_margin_top = 6
		panel.content_margin_bottom = 8
		panel.shadow_color = Color(0, 0, 0, 0.35)
		panel.shadow_size = 4
		block.add_theme_stylebox_override("panel", panel)
		block.modulate = Color(1, 1, 1, 1)


func _style_bars() -> void:
	_apply_bar_style(
		hp_bar,
		Palette.with_alpha(Palette.CRIMSON_DIM, 0.95),
		Palette.CRIMSON,
		Palette.CRIMSON_BRIGHT
	)
	_apply_bar_style(
		breath_bar,
		Palette.with_alpha(Palette.WATER_DIM, 0.95),
		Palette.WATER,
		Palette.WATER_BRIGHT
	)
	for lbl: Label in [hp_label, breath_label, coins_label]:
		if lbl == null:
			continue
		lbl.add_theme_font_size_override("font_size", 20 if lbl != coins_label else 26)
		lbl.add_theme_color_override("font_color", Palette.CREAM)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		lbl.add_theme_constant_override("outline_size", 3)


func _apply_bar_style(bar: ProgressBar, bg: Color, fill: Color, fill_hi: Color) -> void:
	if bar == null:
		return
	var bg_box := StyleBoxFlat.new()
	bg_box.bg_color = bg
	bg_box.border_color = Palette.with_alpha(Palette.GOLD, 0.5)
	bg_box.set_border_width_all(1)
	bg_box.set_corner_radius_all(8)
	bg_box.content_margin_left = 3
	bg_box.content_margin_top = 3
	bg_box.content_margin_right = 3
	bg_box.content_margin_bottom = 3
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = fill
	fill_box.set_corner_radius_all(6)
	# Rim-light sutil no topo do preenchimento — leitura "premium" sem custo de shader.
	fill_box.border_color = fill_hi
	fill_box.border_width_top = 2
	bar.add_theme_stylebox_override("background", bg_box)
	bar.add_theme_stylebox_override("fill", fill_box)
	bar.custom_minimum_size.y = 26
	bar.show_percentage = false
	bar.modulate = Color(1, 1, 1, 1)
