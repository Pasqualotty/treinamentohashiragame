extends Control
## Tela de nome de caçador. Dois modos, mesma cena:
##   - onboarding (primeiro boot): não dá para sair sem confirmar um nome;
##   - edição (veio do badge de perfil no hub): mostra Cancelar e pré-preenche.
## O modo chega por `SceneRouter.name_entry_edit_mode`, setado em `to_name_entry()`.

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var name_input: LineEdit = %NameInput
@onready var hint_label: Label = %HintLabel
@onready var random_btn: Button = %RandomButton
@onready var confirm_btn: Button = %ConfirmButton
@onready var cancel_btn: Button = %CancelButton
@onready var bg_art: TextureRect = %BgArt

const BG_PATH := "res://assets/ui/hub/bg_frame_00.png"

## Nomes temáticos para o botão "sortear". Todos cabem em Game.MAX_PLAYER_NAME_LEN.
const RANDOM_NAMES: Array[String] = [
	"Kamado",
	"Brasa Errante",
	"Caçador do Sol",
	"Névoa de Kiri",
	"Sopro de Água",
	"Lâmina Serena",
	"Chama Noturna",
	"Passo de Jade",
	"Vento Carmesim",
	"Filho da Neve",
	"Guarda do Sol",
	"Trovão Azul",
	"Punho de Ferro",
	"Aurora de Aço",
]

var _edit_mode: bool = false
## Guarda de reentrancia da navegacao. A cortina do SceneRouter tem
## `mouse_filter = STOP`, o que barra clique mas NAO barra teclado: um segundo
## Enter (ou duplo-toque no "Done" do teclado virtual do Android) dentro da janela
## do fade caia no ramo `_transition.is_busy()` do `go_to` e instanciava o hub
## duas vezes — corte seco seguido de fade, `_ready` e BGM em dobro.
var _navigating: bool = false


func _ready() -> void:
	_edit_mode = SceneRouter.name_entry_edit_mode
	if bg_art.texture == null and ResourceLoader.exists(BG_PATH):
		bg_art.texture = load(BG_PATH) as Texture2D

	_style_panel()
	_style_actions()
	_apply_mode_copy()

	name_input.max_length = Game.MAX_PLAYER_NAME_LEN
	if _edit_mode:
		name_input.text = Game.player_name
	_validate()

	# Foco automático: teclado físico e virtual já abrem prontos para digitar.
	name_input.grab_focus()
	if _edit_mode:
		name_input.select_all()

	# O router avisa quando a troca de cena não aconteceu — sem isso a guarda
	# `_navigating` ficaria armada para sempre e a tela viraria um beco sem saída.
	if not SceneRouter.navigation_failed.is_connected(_on_navigation_failed):
		SceneRouter.navigation_failed.connect(_on_navigation_failed)

	if is_instance_valid(Audio):
		Audio.play_bgm("hub")


## Navegação falhou: destrava para o jogador poder tentar de novo ou cancelar.
func _on_navigation_failed(_path: String) -> void:
	_navigating = false


func _apply_mode_copy() -> void:
	if _edit_mode:
		title_label.text = "Trocar de nome"
		subtitle_label.text = "Como o dojo deve te chamar a partir de agora?"
		confirm_btn.text = "SALVAR"
	else:
		title_label.text = "Qual é o seu nome, caçador?"
		subtitle_label.text = "É assim que o dojo vai te chamar daqui pra frente."
		confirm_btn.text = "CONFIRMAR"
	cancel_btn.visible = _edit_mode


## --- Validação ------------------------------------------------------------

func _current_clean_name() -> String:
	return Game.sanitize_player_name(name_input.text)


func _validate() -> void:
	var clean := _current_clean_name()
	confirm_btn.disabled = clean.is_empty()
	if clean.is_empty():
		hint_label.text = "Escolha um nome com pelo menos 1 caractere."
		hint_label.add_theme_color_override("font_color", Palette.with_alpha(Palette.CREAM, 0.6))
	else:
		hint_label.text = "%d/%d caracteres" % [clean.length(), Game.MAX_PLAYER_NAME_LEN]
		hint_label.add_theme_color_override("font_color", Palette.with_alpha(Palette.CREAM, 0.55))


func _on_name_changed(_new_text: String) -> void:
	_validate()


## --- Ações ----------------------------------------------------------------

func _on_name_submitted(_text: String) -> void:
	_confirm()


func _on_confirm_pressed() -> void:
	_confirm()


## Consome a intenção de confirmar. Retorna true só na PRIMEIRA chamada com nome
## válido; as seguintes (Enter repetido dentro do fade) devolvem false. Separado
## de `_confirm` para ser testável sem disparar troca de cena de verdade.
func _claim_submit() -> bool:
	if _navigating:
		return false
	# `set_player_name` sanitiza de novo e persiste; false = nome inválido.
	# A guarda só arma DEPOIS do nome válido: nome ruim não pode travar a tela.
	if not Game.set_player_name(name_input.text):
		_validate()
		return false
	_navigating = true
	return true


func _confirm() -> bool:
	if not _claim_submit():
		return false
	_ui_click()
	if not SceneRouter.to_hub():
		# Recusado na porta (já havia navegação no ar): destrava aqui mesmo, não
		# vem sinal nenhum nesse caso.
		_navigating = false
		return false
	return true


func _on_random_pressed() -> void:
	_ui_click()
	var current := _current_clean_name()
	var pool: Array[String] = RANDOM_NAMES.filter(func(n: String) -> bool: return n != current)
	if pool.is_empty():
		pool = RANDOM_NAMES
	name_input.text = pool[randi() % pool.size()]
	name_input.caret_column = name_input.text.length()
	name_input.grab_focus()
	_validate()


func _on_cancel_pressed() -> void:
	# Mesma guarda do confirmar: ESC repetido (ou ESC logo após o Enter) não pode
	# disparar uma segunda troca de cena por cima da que já está no ar.
	if _navigating:
		return
	_navigating = true
	_ui_click()
	if not SceneRouter.to_hub():
		_navigating = false


func _unhandled_input(event: InputEvent) -> void:
	# ESC volta só no modo edição — no onboarding não há para onde voltar.
	if _edit_mode and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()


func _ui_click() -> void:
	if is_instance_valid(Audio):
		Audio.play_sfx("ui_click")


## --- Estilo ---------------------------------------------------------------

func _style_panel() -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.with_alpha(Palette.PANEL, 0.94)
	style.border_color = Palette.with_alpha(Palette.GOLD, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 34
	style.content_margin_bottom = 34
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)

	var field := StyleBoxFlat.new()
	field.bg_color = Palette.with_alpha(Palette.NIGHT_BG, 0.95)
	field.border_color = Palette.with_alpha(Palette.GOLD, 0.45)
	field.set_border_width_all(2)
	field.set_corner_radius_all(10)
	field.content_margin_left = 16
	field.content_margin_right = 16
	field.content_margin_top = 12
	field.content_margin_bottom = 12
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = Palette.GOLD
	name_input.add_theme_stylebox_override("normal", field)
	name_input.add_theme_stylebox_override("focus", field_focus)
	name_input.add_theme_color_override("font_color", Palette.CREAM)
	name_input.add_theme_color_override("font_placeholder_color", Palette.with_alpha(Palette.CREAM, 0.35))
	name_input.add_theme_color_override("caret_color", Palette.GOLD)


## Hierarquia das ações: confirmar é placa dourada (mesma linguagem do CTA do hub),
## sortear e cancelar ficam fantasmas para não competirem com ela.
func _style_actions() -> void:
	_apply_cta_style(confirm_btn)
	_apply_ghost_style(random_btn)
	_apply_ghost_style(cancel_btn)


func _apply_cta_style(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.GOLD
	normal.border_color = Palette.with_alpha(Palette.INK, 0.85)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 5

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Palette.GOLD_BRIGHT
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Palette.GOLD.darkened(0.22)
	pressed.shadow_size = 0
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = Palette.WATER_BRIGHT
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Palette.with_alpha(Palette.GOLD_DIM, 0.55)
	disabled.border_color = Palette.with_alpha(Palette.INK, 0.35)
	disabled.shadow_size = 0

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Palette.NIGHT_BG)
	btn.add_theme_color_override("font_hover_color", Palette.INK)
	btn.add_theme_color_override("font_pressed_color", Palette.INK)
	btn.add_theme_color_override("font_focus_color", Palette.NIGHT_BG)
	btn.add_theme_color_override("font_disabled_color", Palette.with_alpha(Palette.CREAM, 0.45))


func _apply_ghost_style(btn: Button) -> void:
	if btn == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.with_alpha(Palette.PANEL, 0.0)
	normal.border_color = Palette.with_alpha(Palette.CREAM, 0.22)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(12)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Palette.with_alpha(Palette.CREAM, 0.08)
	hover.border_color = Palette.with_alpha(Palette.GOLD, 0.7)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Palette.with_alpha(Palette.INK, 0.45)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = Palette.WATER_BRIGHT

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_color_override("font_color", Palette.with_alpha(Palette.CREAM, 0.82))
	btn.add_theme_color_override("font_hover_color", Palette.GOLD_BRIGHT)
