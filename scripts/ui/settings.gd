extends Control
## Tela de Ajustes — volume Master/BGM/SFX ligados ao autoload Audio.
## Sliders refletem Audio.volume_* no _ready e persistem via Audio.set_volume_*
## (que já chama Game.save_game() internamente).

@onready var master_slider: HSlider = %MasterSlider
@onready var bgm_slider: HSlider = %BgmSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var master_value: Label = %MasterValueLabel
@onready var bgm_value: Label = %BgmValueLabel
@onready var sfx_value: Label = %SfxValueLabel
@onready var panel: PanelContainer = %Panel
@onready var back_btn: Button = %BackButton
@onready var credits_btn: Button = %CreditsButton

var _sliders: Array[HSlider] = []


func _ready() -> void:
	_sliders = [master_slider, bgm_slider, sfx_slider]
	_style_panel()
	_style_sliders()
	_load_current_volumes()
	if is_instance_valid(Audio):
		Audio.play_bgm("hub")


func _load_current_volumes() -> void:
	var m: float = Audio.volume_master if is_instance_valid(Audio) else 1.0
	var b: float = Audio.volume_bgm if is_instance_valid(Audio) else 0.75
	var s: float = Audio.volume_sfx if is_instance_valid(Audio) else 1.0
	if master_slider:
		master_slider.set_value_no_signal(m)
	if bgm_slider:
		bgm_slider.set_value_no_signal(b)
	if sfx_slider:
		sfx_slider.set_value_no_signal(s)
	_refresh_value_label(master_value, m)
	_refresh_value_label(bgm_value, b)
	_refresh_value_label(sfx_value, s)


func _refresh_value_label(lbl: Label, linear: float) -> void:
	if lbl:
		lbl.text = "%d%%" % int(round(linear * 100.0))


## --- Sinais dos sliders ---------------------------------------------------

func _on_master_changed(value: float) -> void:
	_refresh_value_label(master_value, value)
	if is_instance_valid(Audio):
		Audio.set_volume_master(value)


func _on_bgm_changed(value: float) -> void:
	_refresh_value_label(bgm_value, value)
	if is_instance_valid(Audio):
		Audio.set_volume_bgm(value)


func _on_sfx_changed(value: float) -> void:
	_refresh_value_label(sfx_value, value)
	if is_instance_valid(Audio):
		Audio.set_volume_sfx(value)


func _on_sfx_drag_ended(value_changed: bool) -> void:
	# Preview sonoro só ao soltar o slider — evita spam de SFX durante o arraste.
	if value_changed and is_instance_valid(Audio):
		Audio.play_sfx("ui_click")


## --- Navegação --------------------------------------------------------

func _on_back_pressed() -> void:
	_ui_click()
	SceneRouter.to_hub()


func _on_credits_pressed() -> void:
	_ui_click()
	SceneRouter.to_credits()


func _ui_click() -> void:
	if is_instance_valid(Audio):
		Audio.play_sfx("ui_click")


## --- Estilo / paleta --------------------------------------------------

func _style_panel() -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.with_alpha(Palette.PANEL, 0.92)
	style.border_color = Palette.with_alpha(Palette.GOLD, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)


func _style_sliders() -> void:
	for s in _sliders:
		if s == null:
			continue
		var groove := StyleBoxFlat.new()
		groove.bg_color = Palette.with_alpha(Palette.NIGHT_BG, 0.9)
		groove.border_color = Palette.with_alpha(Palette.GOLD, 0.4)
		groove.set_border_width_all(1)
		groove.set_corner_radius_all(6)
		groove.content_margin_top = 8
		groove.content_margin_bottom = 8
		var fill := StyleBoxFlat.new()
		fill.bg_color = Palette.GOLD
		fill.set_corner_radius_all(6)
		s.add_theme_stylebox_override("slider", groove)
		s.add_theme_stylebox_override("grabber_area", fill)
		s.add_theme_stylebox_override("grabber_area_highlight", fill)
