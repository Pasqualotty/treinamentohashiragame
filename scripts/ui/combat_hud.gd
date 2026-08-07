extends CanvasLayer
## HUD de combate — painéis lacados, ícones HP/respiração, moedas.

@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var breath_bar: ProgressBar = %BreathBar
@onready var breath_label: Label = %BreathLabel
@onready var coins_label: Label = %CoinsLabel
@onready var coins_icon: TextureRect = %CoinsIcon

const TEX_HEART := "res://assets/ui/icons/hp_heart.png"
const TEX_BREATH := "res://assets/ui/icons/breath_orb.png"
const TEX_COIN := "res://assets/ui/icons/coin.png"

var _hp: float = 100.0
var _hp_max: float = 100.0


func _ready() -> void:
	_style_chrome()
	_style_bars()
	_bind_icons()
	set_hp(_hp, _hp_max)
	_refresh_breath(Game.breath, Game.breath_max)
	_refresh_coins(Game.coins_run)
	if not Game.breath_changed.is_connected(_on_breath_changed):
		Game.breath_changed.connect(_on_breath_changed)
	if not Game.run_coins_changed.is_connected(_on_run_coins_changed):
		Game.run_coins_changed.connect(_on_run_coins_changed)


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
	else:
		breath_bar.modulate = Color.WHITE


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
	# Painéis escuros atrás das barras.
	for path: String in ["HpBlock", "BreathBlock", "CoinsBlock"]:
		var block := find_child(path, true, false) as Control
		if block == null:
			continue
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.06, 0.05, 0.09, 0.72)
		panel.border_color = Color(0.78, 0.62, 0.22, 0.75)
		panel.set_border_width_all(2)
		panel.set_corner_radius_all(10)
		panel.content_margin_left = 10
		panel.content_margin_right = 10
		panel.content_margin_top = 6
		panel.content_margin_bottom = 8
		block.add_theme_stylebox_override("panel", panel)
		# Se for VBox/HBox, envolve com painel visual via modulate suave
		block.modulate = Color(1, 1, 1, 1)


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
		lbl.add_theme_color_override("font_color", Color(1, 0.96, 0.9, 1))
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
