extends Control
## Hub: fundo animado (Ken Burns), botões temáticos, Tanjiro idle+blink.

@onready var coins_label: Label = %CoinsLabel
@onready var character_name: Label = %CharacterName
@onready var character_art: TextureRect = %CharacterArt
@onready var bg_art: TextureRect = %BgArt
@onready var shop_btn: Button = %ShopButton
@onready var chars_btn: Button = %CharactersButton
@onready var play_btn: Button = %PlayButton
@onready var settings_btn: Button = %SettingsButton

const HUB_IDLE_DIR := "res://assets/characters/player/hub_idle"
const BG_DIR := "res://assets/ui/hub"
const BTN_DIR := "res://assets/ui/buttons"

# 00 open, 01 breathe, 02 open, 03 blink, 04 open, 05 open, 06 slash, 07 overhead
const FRAME_DURATIONS: Array[float] = [0.70, 0.40, 0.55, 0.12, 0.45, 0.35, 0.30, 0.35]
const BG_FRAME_TIME: float = 1.35

var _frames: Array[Texture2D] = []
var _frame_i: int = 0
var _timer: float = 0.0

var _bg_frames: Array[Texture2D] = []
var _bg_i: int = 0
var _bg_timer: float = 0.0
var _bg_dir: int = 1


func _ready() -> void:
	_load_idle_frames()
	_load_bg_frames()
	_style_buttons()
	if _frames.size() > 0:
		character_art.texture = _frames[0]
		character_art.visible = true
	if _bg_frames.size() > 0:
		bg_art.texture = _bg_frames[0]
	_refresh()
	if not Game.coins_changed.is_connected(_on_coins_changed):
		Game.coins_changed.connect(_on_coins_changed)


func _process(delta: float) -> void:
	_tick_character(delta)
	_tick_background(delta)


func _tick_character(delta: float) -> void:
	if _frames.size() < 2:
		return
	_timer += delta
	var dur: float = FRAME_DURATIONS[_frame_i % FRAME_DURATIONS.size()]
	if _timer >= dur:
		_timer = 0.0
		_frame_i = (_frame_i + 1) % _frames.size()
		character_art.texture = _frames[_frame_i]


func _tick_background(delta: float) -> void:
	if _bg_frames.size() < 2:
		return
	_bg_timer += delta
	if _bg_timer >= BG_FRAME_TIME:
		_bg_timer = 0.0
		_bg_i += _bg_dir
		if _bg_i >= _bg_frames.size() - 1:
			_bg_i = _bg_frames.size() - 1
			_bg_dir = -1
		elif _bg_i <= 0:
			_bg_i = 0
			_bg_dir = 1
		bg_art.texture = _bg_frames[_bg_i]
	# leve drift contínuo
	var t := Time.get_ticks_msec() * 0.00015
	bg_art.position.x = sin(t) * 8.0
	bg_art.position.y = cos(t * 0.7) * 5.0


func _load_idle_frames() -> void:
	_frames.clear()
	# 00..07 se existirem (idle + 2 golpes)
	for i in range(8):
		var path := "%s/%02d.png" % [HUB_IDLE_DIR, i]
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				_frames.append(tex)
	if _frames.is_empty():
		var fallback := "res://assets/characters/player/tanjiro_hub_idle_00.png"
		if ResourceLoader.exists(fallback):
			_frames.append(load(fallback) as Texture2D)


func _load_bg_frames() -> void:
	_bg_frames.clear()
	for i in range(5):
		var path := "%s/bg_frame_%02d.png" % [BG_DIR, i]
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex:
				_bg_frames.append(tex)
	if _bg_frames.is_empty():
		var still := "%s/bg_still.png" % BG_DIR
		if ResourceLoader.exists(still):
			_bg_frames.append(load(still) as Texture2D)


func _style_buttons() -> void:
	_apply_stylebox(shop_btn, "%s/btn_shop.png" % BTN_DIR, Color(0.95, 0.9, 0.75))
	_apply_stylebox(chars_btn, "%s/btn_chars.png" % BTN_DIR, Color(0.95, 0.9, 0.75))
	_apply_stylebox(play_btn, "%s/btn_play.png" % BTN_DIR, Color(0.15, 0.08, 0.05))
	_apply_icon_button(settings_btn, "%s/settings_gear.png" % BTN_DIR)


func _apply_stylebox(btn: Button, tex_path: String, font_color: Color) -> void:
	if not ResourceLoader.exists(tex_path):
		return
	var tex := load(tex_path) as Texture2D
	var normal := StyleBoxTexture.new()
	normal.texture = tex
	normal.texture_margin_left = 18
	normal.texture_margin_top = 12
	normal.texture_margin_right = 18
	normal.texture_margin_bottom = 12
	var hover := normal.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.08, 1.05, 0.95)
	var pressed := normal.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.85, 0.82, 0.75)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color.lightened(0.1))
	btn.add_theme_color_override("font_pressed_color", font_color.darkened(0.15))
	btn.add_theme_font_size_override("font_size", 20 if btn != play_btn else 28)


func _apply_icon_button(btn: Button, tex_path: String) -> void:
	if not ResourceLoader.exists(tex_path):
		return
	var tex := load(tex_path) as Texture2D
	btn.icon = tex
	btn.text = ""
	btn.expand_icon = true
	btn.custom_minimum_size = Vector2(48, 48)
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)


func _refresh() -> void:
	coins_label.text = "🪙 %d" % Game.coins_banked
	character_name.text = "Tanjiro"


func _on_coins_changed(_total: int) -> void:
	_refresh()


func _on_play_pressed() -> void:
	SceneRouter.to_world_map()


func _on_shop_pressed() -> void:
	SceneRouter.to_shop()


func _on_characters_pressed() -> void:
	pass


func _on_settings_pressed() -> void:
	pass
