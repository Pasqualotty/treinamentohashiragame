extends CanvasLayer
## HUD de combate reutilizável (HP, respiração, moedas da run).
##
## Integração na fase futura:
##   1. Instancie `res://scenes/ui/combat_hud.tscn` como filho da cena de battle
##      (ou `var hud = preload(...).instantiate(); add_child(hud)`).
##   2. Chame `set_hp(current, max)` no spawn do player e em todo dano/cura.
##   3. Respiração e moedas da run ligam sozinhas nos sinais do autoload `Game`
##      (`breath_changed`, `run_coins_changed`).
##   4. Em drop de moeda: `Game.add_run_coins(n)`. Em hit: `Game.add_breath_from_hit()`.
##   5. Não use `coins_changed` aqui — o payload mistura banked/run; hub usa banked.
##
## Layout: top safe area em viewport 1280×720. Legível em mobile (fontes ≥20, barras altas).

@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var breath_bar: ProgressBar = %BreathBar
@onready var breath_label: Label = %BreathLabel
@onready var coins_label: Label = %CoinsLabel
@onready var coins_icon: TextureRect = %CoinsIcon

var _hp: float = 100.0
var _hp_max: float = 100.0


func _ready() -> void:
	_style_bars()
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
	breath_label.text = "ULT" if is_full else "%d%%" % int(round(value / m * 100.0))
	# Glow sutil quando ultimate pronta
	if is_full:
		breath_bar.modulate = Color(1.15, 1.2, 1.35, 1.0)
	else:
		breath_bar.modulate = Color.WHITE


func _refresh_coins(run_total: int) -> void:
	coins_label.text = str(run_total)


func _style_bars() -> void:
	_apply_bar_style(
		hp_bar,
		Color(0.12, 0.08, 0.1, 0.88),
		Color(0.85, 0.18, 0.22, 1.0)
	)
	_apply_bar_style(
		breath_bar,
		Color(0.08, 0.1, 0.18, 0.88),
		Color(0.357, 0.553, 0.937, 1.0)  # #5B8DEF STYLE-BIBLE
	)
	# Tipografia limpa / legível em mobile (sem depender só do .tscn).
	if hp_label:
		hp_label.add_theme_font_size_override("font_size", 20)
		hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		hp_label.add_theme_constant_override("outline_size", 2)
	if breath_label:
		breath_label.add_theme_font_size_override("font_size", 20)
		breath_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		breath_label.add_theme_constant_override("outline_size", 2)
	if coins_label:
		coins_label.add_theme_font_size_override("font_size", 28)
		coins_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		coins_label.add_theme_constant_override("outline_size", 2)


func _apply_bar_style(bar: ProgressBar, bg: Color, fill: Color) -> void:
	var bg_box := StyleBoxFlat.new()
	bg_box.bg_color = bg
	bg_box.set_corner_radius_all(6)
	bg_box.content_margin_left = 2
	bg_box.content_margin_top = 2
	bg_box.content_margin_right = 2
	bg_box.content_margin_bottom = 2
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = fill
	fill_box.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg_box)
	bar.add_theme_stylebox_override("fill", fill_box)
	bar.show_percentage = false
