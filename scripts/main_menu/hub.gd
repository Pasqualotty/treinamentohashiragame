extends Control
## Hub: fundo com respiração (Ken Burns + cross-fade), placas de botão com ícone
## e Tanjiro em idle real (sem golpe no meio da animação).
##
## Movimento do fundo e piscada do personagem são conduzidos por Tween — nada de
## `Time.get_ticks_msec()` cru no `_process` nem de escrita direta em `position`
## de Control ancorado (era isso que fazia o fundo tremer).

@onready var coins_label: Label = %CoinsLabel
@onready var coins_badge: PanelContainer = %CoinsBadge
@onready var character_name: Label = %CharacterName
@onready var character_art: TextureRect = %CharacterArt
@onready var showcase: Control = %CenterShowcase
@onready var platform_glow: Control = %PlatformGlow
@onready var bg_layer: Control = %BgLayer
@onready var bg_a: TextureRect = %BgArtA
@onready var bg_b: TextureRect = %BgArtB
@onready var profile_btn: Button = %ProfileButton
@onready var shop_btn: Button = %ShopButton
@onready var chars_btn: Button = %CharactersButton
@onready var play_btn: Button = %PlayButton
@onready var settings_btn: Button = %SettingsButton

const HUB_IDLE_DIR := "res://assets/characters/player/hub_idle"
const BG_DIR := "res://assets/ui/hub"
const PLATE_DIR := "res://assets/ui/buttons/hub"

## Frames do hub_idle: 00 é a pose neutra e 03 é a piscada. 01 é outra pose
## (calçado e katana diferentes) e 06/07 são golpes de combate — nenhum dos três
## pertence a um loop de idle: era daí que vinha o personagem "bugado" no menu.
const IDLE_FRAME := 0
const BLINK_FRAME := 3

const BLINK_HOLD := 0.11
const BLINK_INTERVAL_MIN := 3.2
const BLINK_INTERVAL_MAX := 6.8

## Respiração: escala mínima com pivô nos pés — o peito sobe, os pés não saem do chão.
const BREATH_SCALE := Vector2(1.006, 1.014)
const BREATH_PERIOD := 2.6

## Ken Burns do fundo: monotônico dentro de cada perna, ping-pong com ease sine.
const KENBURNS_SCALE := 1.06
const KENBURNS_PERIOD := 18.0
## Cross-fade entre frames do fundo: segura, dissolve, segura.
const BG_HOLD := 5.0
const BG_FADE := 1.6

## Proporção do canvas dos frames de hub_idle (640x900).
const CHAR_ASPECT := 640.0 / 900.0
## Espaço reservado acima (nome do personagem) e abaixo (centro do glow) da arte.
const CHAR_TOP_MARGIN := 48.0
const CHAR_FEET_MARGIN := 36.0
## Largura do glow em relação à largura desenhada do personagem.
const GLOW_WIDTH_RATIO := 1.25
const GLOW_HEIGHT := 64.0

const PULSE_PERIOD := 0.9
const PULSE_COLOR := Color(1.12, 1.08, 0.85, 1.0)

var _idle_tex: Texture2D
var _blink_tex: Texture2D

var _bg_frames: Array[Texture2D] = []
var _bg_i: int = 0

var _play_pulse_tween: Tween
var _breath_tween: Tween
var _blink_tween: Tween
var _bg_tween: Tween
var _kenburns_tween: Tween

## Guarda de reentrancia da navegacao (mesma classe de bug da tela de nome): a
## cortina do SceneRouter so bloqueia mouse, e mesmo o mouse escapa em duplo-clique
## rapido antes de a cortina existir. Sem isto, o segundo toque cai no ramo
## `is_busy()` do `go_to` e troca de cena na marra por cima da transicao.
var _navigating: bool = false


func _ready() -> void:
	_load_idle_frames()
	_load_bg_frames()
	_style_buttons()
	_style_chrome()

	if _idle_tex != null:
		character_art.texture = _idle_tex
		character_art.visible = true
	if not _bg_frames.is_empty():
		bg_a.texture = _bg_frames[0]

	_refresh()
	if not Game.coins_changed.is_connected(_on_coins_changed):
		Game.coins_changed.connect(_on_coins_changed)
	if not Game.player_name_changed.is_connected(_on_player_name_changed):
		Game.player_name_changed.connect(_on_player_name_changed)
	if not showcase.resized.is_connected(_layout_showcase):
		showcase.resized.connect(_layout_showcase)
	if not SceneRouter.navigation_failed.is_connected(_on_navigation_failed):
		SceneRouter.navigation_failed.connect(_on_navigation_failed)

	if is_instance_valid(Audio):
		Audio.play_bgm("hub")

	# Espera o layout dos containers assentar antes de fixar pivôs e medir rects.
	await get_tree().process_frame
	_layout_showcase()
	_start_play_pulse()
	_start_breathing()
	_start_blink_loop()
	_start_background()
	# Depois do hub vivo: update nunca trava splash/loading nem o primeiro frame.
	call_deferred("_request_update_check")


## --- Layout do showcase ---------------------------------------------------

## Dimensiona a arte pela altura disponível preservando a proporção e ancora os
## pés no centro do PlatformGlow. `CenterShowcase` é um Control puro (não é
## Container), então definir position/size aqui é estável — nada reposiciona depois.
func _layout_showcase() -> void:
	if showcase == null or character_art == null:
		return
	var avail_h: float = maxf(1.0, showcase.size.y - CHAR_TOP_MARGIN - CHAR_FEET_MARGIN)
	var h: float = avail_h
	var w: float = h * CHAR_ASPECT
	if w > showcase.size.x:
		w = showcase.size.x
		h = w / CHAR_ASPECT
	var feet_y: float = showcase.size.y - CHAR_FEET_MARGIN
	character_art.size = Vector2(w, h)
	character_art.position = Vector2((showcase.size.x - w) * 0.5, feet_y - h)
	# Pivô nos pés: a respiração levanta o tronco sem descolar do chão.
	character_art.pivot_offset = Vector2(w * 0.5, h)

	if platform_glow != null:
		var gw: float = w * GLOW_WIDTH_RATIO
		platform_glow.size = Vector2(gw, GLOW_HEIGHT)
		platform_glow.position = Vector2(
			(showcase.size.x - gw) * 0.5, feet_y - GLOW_HEIGHT * 0.5)


## --- Personagem -----------------------------------------------------------

func _load_idle_frames() -> void:
	_idle_tex = _load_tex("%s/%02d.png" % [HUB_IDLE_DIR, IDLE_FRAME])
	_blink_tex = _load_tex("%s/%02d.png" % [HUB_IDLE_DIR, BLINK_FRAME])
	if _idle_tex == null:
		_idle_tex = _load_tex("res://assets/characters/player/tanjiro_hub_idle_00.png")
	if _idle_tex == null:
		push_warning("Hub: nenhum frame de idle encontrado em %s" % HUB_IDLE_DIR)


func _start_breathing() -> void:
	if character_art == null or _idle_tex == null:
		return
	if _breath_tween and _breath_tween.is_valid():
		_breath_tween.kill()
	_breath_tween = create_tween().set_loops()
	_breath_tween.tween_property(character_art, "scale", BREATH_SCALE, BREATH_PERIOD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath_tween.tween_property(character_art, "scale", Vector2.ONE, BREATH_PERIOD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_blink_loop() -> void:
	if _blink_tex == null or _idle_tex == null:
		return
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	_queue_next_blink()


## Uma piscada curta em janela aleatória — o resto do tempo fica na pose neutra.
func _queue_next_blink() -> void:
	_blink_tween = create_tween()
	_blink_tween.tween_interval(randf_range(BLINK_INTERVAL_MIN, BLINK_INTERVAL_MAX))
	_blink_tween.tween_callback(_show_blink_frame)
	_blink_tween.tween_interval(BLINK_HOLD)
	_blink_tween.tween_callback(_show_idle_frame)
	_blink_tween.tween_callback(_queue_next_blink)


func _show_blink_frame() -> void:
	character_art.texture = _blink_tex


func _show_idle_frame() -> void:
	character_art.texture = _idle_tex


## --- Fundo ----------------------------------------------------------------

## O último frame do set é cópia do primeiro (bg_frame_04 == bg_frame_00), então o
## ciclo é para a frente com wrap: a volta 04→00 dissolve entre imagens iguais e
## não aparece. Ping-pong não é necessário e deixaria uma parada no fim do ciclo.
func _load_bg_frames() -> void:
	_bg_frames.clear()
	for i in range(8):
		var path := "%s/bg_frame_%02d.png" % [BG_DIR, i]
		if not ResourceLoader.exists(path):
			continue
		var tex := _load_tex(path)
		if tex != null:
			_bg_frames.append(tex)
	if _bg_frames.is_empty():
		var still := _load_tex("%s/bg_still.png" % BG_DIR)
		if still != null:
			_bg_frames.append(still)


func _start_background() -> void:
	_start_kenburns()
	if _bg_frames.size() < 2:
		return
	_queue_next_bg_step()


## Zoom lento e contínuo. Escala é transform pós-layout: não briga com âncoras
## (escrever em `position` de um Control ancorado é o que tremia antes).
func _start_kenburns() -> void:
	if bg_layer == null:
		return
	bg_layer.pivot_offset = bg_layer.size * 0.5
	if _kenburns_tween and _kenburns_tween.is_valid():
		_kenburns_tween.kill()
	var zoom := Vector2(KENBURNS_SCALE, KENBURNS_SCALE)
	_kenburns_tween = create_tween().set_loops()
	_kenburns_tween.tween_property(bg_layer, "scale", zoom, KENBURNS_PERIOD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_kenburns_tween.tween_property(bg_layer, "scale", Vector2.ONE, KENBURNS_PERIOD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _queue_next_bg_step() -> void:
	_bg_tween = create_tween()
	_bg_tween.tween_interval(BG_HOLD)
	_bg_tween.tween_callback(_prepare_bg_crossfade)
	# Dissolve o frame de cima; a camada de baixo ainda segura o frame anterior.
	_bg_tween.tween_property(bg_b, "modulate:a", 1.0, BG_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bg_tween.tween_callback(_commit_bg_crossfade)
	_bg_tween.tween_callback(_queue_next_bg_step)


func _prepare_bg_crossfade() -> void:
	_bg_i = (_bg_i + 1) % _bg_frames.size()
	bg_b.texture = _bg_frames[_bg_i]
	bg_b.modulate.a = 0.0


## Troca sem piscar: no instante do commit as duas camadas mostram o mesmo frame.
func _commit_bg_crossfade() -> void:
	bg_a.texture = bg_b.texture
	bg_b.modulate.a = 0.0


## --- Botões e chrome ------------------------------------------------------

func _style_buttons() -> void:
	_apply_plate(shop_btn, "shop", Palette.CREAM)
	_apply_plate(chars_btn, "chars", Palette.CREAM)
	# CTA: placa dourada, então o rótulo vai em tinta escura para contrastar.
	_apply_plate(play_btn, "play", Palette.NIGHT_BG)
	# Placa redonda com engrenagem gravada — o "⚙" do .tscn é só o fallback.
	if _apply_plate(settings_btn, "settings", Palette.CREAM, true):
		settings_btn.text = ""


## Placa laqueada gerada por tools/gen_hub_art.py, um PNG por estado. Retorna
## false se o asset não existir — aí o botão fica com o estilo do tema global,
## ainda legível e clicável.
func _apply_plate(btn: Button, plate: String, font_color: Color,
		circular: bool = false) -> bool:
	if btn == null:
		return false
	var normal := _plate_style(plate, "normal", circular)
	if normal == null:
		return false
	btn.add_theme_stylebox_override("normal", normal)
	for state in ["hover", "pressed", "focus"]:
		var sb := _plate_style(plate, state, circular)
		btn.add_theme_stylebox_override(state, sb if sb != null else normal)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color.lightened(0.12))
	btn.add_theme_color_override("font_pressed_color", font_color.darkened(0.15))
	btn.add_theme_color_override("font_focus_color", font_color)
	return true


## Margens de conteúdo abrem espaço para o medalhão gravado à esquerda da placa;
## as margens de textura (9-slice) protegem cantos e medalhão se a placa esticar.
## Placa redonda não é fatiável — desenha inteira, esticando se preciso.
func _plate_style(plate: String, state: String, circular: bool) -> StyleBoxTexture:
	var tex := _load_tex("%s/%s_%s.png" % [PLATE_DIR, plate, state])
	if tex == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	if circular:
		return sb
	var medallion: float = tex.get_height() * 0.86
	sb.texture_margin_left = medallion
	sb.texture_margin_right = 22
	sb.texture_margin_top = 20
	sb.texture_margin_bottom = 20
	sb.content_margin_left = medallion + 14
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb


func _style_chrome() -> void:
	_apply_badge_style(coins_badge)
	_apply_profile_style(profile_btn)


func _badge_stylebox(border_alpha: float, bg_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.with_alpha(Palette.PANEL, bg_alpha)
	style.border_color = Palette.with_alpha(Palette.GOLD, border_alpha)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _apply_badge_style(panel: PanelContainer) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", _badge_stylebox(0.5, 0.7))


## O badge de perfil é um Button de verdade (foco e navegação por teclado/gamepad
## de graça) estilizado como painel — tocar nele reabre a tela de nome.
func _apply_profile_style(btn: Button) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override("normal", _badge_stylebox(0.5, 0.7))
	btn.add_theme_stylebox_override("hover", _badge_stylebox(0.9, 0.82))
	btn.add_theme_stylebox_override("pressed", _badge_stylebox(0.35, 0.9))
	btn.add_theme_stylebox_override("focus", _badge_stylebox(0.95, 0.82))
	btn.add_theme_color_override("font_color", Palette.CREAM)
	btn.add_theme_color_override("font_hover_color", Palette.GOLD_BRIGHT)
	btn.add_theme_constant_override("h_separation", 10)


func _start_play_pulse() -> void:
	if play_btn == null:
		return
	if _play_pulse_tween and _play_pulse_tween.is_valid():
		_play_pulse_tween.kill()
	play_btn.pivot_offset = play_btn.size * 0.5
	_play_pulse_tween = create_tween()
	_play_pulse_tween.set_loops()
	_play_pulse_tween.tween_property(play_btn, "modulate", PULSE_COLOR, PULSE_PERIOD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_play_pulse_tween.tween_property(play_btn, "modulate", Color(1, 1, 1, 1), PULSE_PERIOD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## --- Estado ---------------------------------------------------------------

func _load_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _refresh() -> void:
	coins_label.text = str(Game.coins_banked)
	character_name.text = "Tanjiro"
	profile_btn.text = Game.player_name if Game.has_player_name() else "Caçador"


func _on_coins_changed(_total: int) -> void:
	_refresh()


func _on_player_name_changed(_new_name: String) -> void:
	_refresh()


func _ui_click() -> void:
	if is_instance_valid(Audio):
		Audio.play_sfx("ui_click")


## --- Navegação ------------------------------------------------------------

## Navegação falhou: destrava os botões. Sem isto, um `change_scene_to_file` que
## dá erro deixaria play/loja/config/perfil mortos de uma vez só.
func _on_navigation_failed(_path: String) -> void:
	_navigating = false


## Único ponto de saída do hub: arma a guarda, chama o router e destrava sozinho
## se o pedido for recusado. Handler novo só precisa passar o `to_*` aqui — não
## há `if err != OK` espalhado para alguém esquecer.
func _navigate(target: Callable) -> void:
	if _navigating:
		return
	_navigating = true
	_ui_click()
	if not bool(target.call()):
		_navigating = false


func _on_play_pressed() -> void:
	_navigate(SceneRouter.to_world_map)


func _on_shop_pressed() -> void:
	_navigate(SceneRouter.to_shop)


func _on_characters_pressed() -> void:
	# Não navega: fica fora da guarda para o jogador poder clicar de novo.
	_ui_click()
	# MVP: so Tanjiro. Tela de elenco completa e pos-MVP.
	character_name.text = "Tanjiro (unico no MVP)"


func _on_settings_pressed() -> void:
	_navigate(SceneRouter.to_settings)


func _on_profile_pressed() -> void:
	_navigate(func() -> bool: return SceneRouter.to_name_entry(true))


func _request_update_check() -> void:
	if not is_instance_valid(AutoUpdater):
		return
	AutoUpdater.check_from_hub()
