extends CanvasLayer
## Aviso de versão nova — overlay no hub, visual do dojo (ouro / painel / Cinzel).
## Textos curtos em português, sem jargão de loja ou de adulto.

signal update_pressed
signal later_pressed
signal retry_pressed
signal play_anyway_pressed
signal permission_pressed
signal cancel_download_pressed

@onready var dim: ColorRect = %Dim
@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var body_label: Label = %BodyLabel
@onready var extra_label: Label = %ExtraLabel
@onready var progress: ProgressBar = %ProgressBar
@onready var primary_btn: Button = %PrimaryButton
@onready var secondary_btn: Button = %SecondaryButton

var _mode: String = "hidden"


func _ready() -> void:
	layer = 80
	_style_panel()
	_style_progress()
	_apply_cta_style(primary_btn)
	_apply_ghost_style(secondary_btn)
	hide_dialog()


func hide_dialog() -> void:
	_mode = "hidden"
	visible = false
	if dim:
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_offer(manifest: UpdateManifest, local_name: String) -> void:
	_mode = "offer"
	title_label.text = "Tem versão nova do treino"
	var remote_name: String = manifest.version_name
	if local_name.is_empty():
		body_label.text = "O Matheus mandou uma atualização. Quer baixar agora?"
	else:
		body_label.text = "Você está na %s. Chegou a %s. Quer baixar agora?" % [local_name, remote_name]
	var extra := ""
	if not manifest.changelog.is_empty():
		extra = manifest.changelog
	var size_s := UpdateManifest.format_size(manifest.size_bytes)
	if not size_s.is_empty():
		if extra.is_empty():
			extra = "O download tem %s." % size_s
		else:
			extra += "\nO download tem %s." % size_s
	extra_label.text = extra
	extra_label.visible = not extra.is_empty()
	progress.visible = false
	primary_btn.text = "ATUALIZAR"
	primary_btn.visible = true
	primary_btn.disabled = false
	secondary_btn.text = "Depois"
	secondary_btn.visible = true
	_open()


func show_downloading(ratio: float) -> void:
	_mode = "downloading"
	title_label.text = "Baixando a versão nova"
	if ratio > 0.0:
		body_label.text = "Espera um pouquinho… %d%%" % int(round(ratio * 100.0))
	else:
		body_label.text = "Espera um pouquinho…"
	extra_label.visible = false
	progress.visible = true
	progress.value = ratio * 100.0
	primary_btn.visible = false
	secondary_btn.text = "Cancelar"
	secondary_btn.visible = true
	_open()


func show_failed() -> void:
	_mode = "failed"
	title_label.text = "Não deu pra baixar"
	body_label.text = "A internet falhou. Tenta de novo ou joga assim mesmo."
	extra_label.visible = false
	progress.visible = false
	primary_btn.text = "TENTAR DE NOVO"
	primary_btn.visible = true
	primary_btn.disabled = false
	secondary_btn.text = "Jogar assim mesmo"
	secondary_btn.visible = true
	_open()


func show_permission() -> void:
	_mode = "permission"
	title_label.text = "O celular precisa deixar"
	body_label.text = "É só uma vez: permite que este jogo instale a versão nova. Depois volta e o download começa."
	extra_label.visible = false
	progress.visible = false
	primary_btn.text = "ABRIR PERMISSÃO"
	primary_btn.visible = true
	primary_btn.disabled = false
	secondary_btn.text = "Depois"
	secondary_btn.visible = true
	_open()


func show_installing() -> void:
	_mode = "installing"
	title_label.text = "Quase lá"
	body_label.text = "Agora o celular vai pedir pra instalar. Aceita — o treino novo abre depois."
	extra_label.visible = false
	progress.visible = false
	primary_btn.visible = false
	secondary_btn.text = "Jogar assim mesmo"
	secondary_btn.visible = true
	_open()


func show_install_blocked() -> void:
	_mode = "blocked"
	title_label.text = "O celular bloqueou"
	body_label.text = "Baixou, mas não abriu o instalador. Em alguns celulares precisa permitir fontes desconhecidas. Pede ajuda pro Matheus."
	extra_label.visible = false
	progress.visible = false
	primary_btn.text = "TENTAR DE NOVO"
	primary_btn.visible = true
	primary_btn.disabled = false
	secondary_btn.text = "Jogar assim mesmo"
	secondary_btn.visible = true
	_open()


func show_desktop_only() -> void:
	_mode = "desktop"
	title_label.text = "Isso só no celular"
	body_label.text = "No computador o update não instala. No telefone do sobrinho, o botão baixa e pede pra instalar."
	extra_label.visible = false
	progress.visible = false
	primary_btn.visible = false
	secondary_btn.text = "Fechar"
	secondary_btn.visible = true
	_open()


func _open() -> void:
	visible = true
	if dim:
		dim.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_primary_pressed() -> void:
	_ui_click()
	match _mode:
		"offer":
			update_pressed.emit()
		"failed", "blocked":
			retry_pressed.emit()
		"permission":
			permission_pressed.emit()


func _on_secondary_pressed() -> void:
	_ui_click()
	match _mode:
		"offer", "permission":
			later_pressed.emit()
		"downloading":
			cancel_download_pressed.emit()
		"failed", "installing", "blocked", "desktop":
			play_anyway_pressed.emit()


func _ui_click() -> void:
	if is_instance_valid(Audio):
		Audio.play_sfx("ui_click")


func _style_panel() -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.with_alpha(Palette.PANEL, 0.96)
	style.border_color = Palette.with_alpha(Palette.GOLD, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 30
	style.content_margin_bottom = 28
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)


func _style_progress() -> void:
	if progress == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Palette.with_alpha(Palette.NIGHT_BG, 0.95)
	bg.set_corner_radius_all(8)
	bg.content_margin_top = 4
	bg.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.GOLD
	fill.set_corner_radius_all(8)
	progress.add_theme_stylebox_override("background", bg)
	progress.add_theme_stylebox_override("fill", fill)


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
