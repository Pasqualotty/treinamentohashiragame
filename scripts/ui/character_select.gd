extends Control
## Tela PERSONAGENS — 15 do catálogo. Locked recusa; unlocked grava o id atual.
## Layout 1280×720: 3 colunas, wrap por palavra, botão de escolha numa linha.

const TOUCH_MIN := 48.0
const CARD_MIN_H := 220.0
const KIT_FONT := 12
const CHOOSE_FONT := 16
const LOCK_FONT := 13

const _UiFont := preload("res://scripts/ui/ui_font.gd")

@onready var grid: GridContainer = %Grid
@onready var status_label: Label = %StatusLabel
@onready var current_label: Label = %CurrentLabel

var _navigating: bool = false


func _ready() -> void:
	_UiFont.ensure_theme_space()
	_lock_header_wrap()
	_rebuild()
	if not SceneRouter.navigation_failed.is_connected(_on_navigation_failed):
		SceneRouter.navigation_failed.connect(_on_navigation_failed)


func _lock_header_wrap() -> void:
	grid.columns = 3
	var title := get_node_or_null("TopBar/Title") as Label
	if title != null:
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.clip_text = false
	current_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	current_label.clip_text = false
	current_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.clip_text = false
	var back := get_node_or_null("BackButton") as Button
	if back != null:
		back.autowrap_mode = TextServer.AUTOWRAP_OFF
		back.clip_text = false
		back.custom_minimum_size = Vector2(168, TOUCH_MIN)
		back.add_theme_font_size_override("font_size", 18)
		_apply_slim_button_styles(back)


func _rebuild() -> void:
	for child in grid.get_children():
		child.queue_free()
	var current: CharacterDef = CharacterCatalog.find(Game.current_character_id)
	if current != null:
		current_label.text = "Em campo: %s" % current.display_name
	else:
		current_label.text = "Em campo: Tanjiro"
	for def: CharacterDef in CharacterCatalog.load_all():
		grid.add_child(_make_card(def))
	status_label.text = "Toque num caçador liberado para levá-lo à fase."


func _make_card(def: CharacterDef) -> Control:
	var unlocked: bool = Game.is_character_unlocked(def.id)
	var selected: bool = def.id == Game.current_character_id

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, CARD_MIN_H)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.with_alpha(Palette.PANEL, 0.94)
	style.border_color = Palette.GOLD if selected else Palette.with_alpha(def.accent, 0.7)
	style.set_border_width_all(3 if selected else 2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	if def.has_portrait_art():
		var face_tex: Texture2D = load(def.portrait_path) as Texture2D
		if face_tex != null:
			var face := TextureRect.new()
			face.texture = face_tex
			face.custom_minimum_size = Vector2(0, 72)
			face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(face)
		else:
			col.add_child(_make_swatch(def))
	else:
		col.add_child(_make_swatch(def))

	var name_lbl := Label.new()
	name_lbl.text = def.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_lbl.clip_text = false
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Palette.CREAM)
	col.add_child(name_lbl)

	var kit_lbl := Label.new()
	kit_lbl.text = "%s · %s" % [def.skill_1_name, def.skill_2_name]
	kit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kit_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kit_lbl.clip_text = false
	kit_lbl.max_lines_visible = 2
	kit_lbl.add_theme_font_size_override("font_size", KIT_FONT)
	kit_lbl.add_theme_color_override("font_color", Palette.with_alpha(Palette.CREAM, 0.75))
	col.add_child(kit_lbl)

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_ALL
	btn.custom_minimum_size = Vector2(0, TOUCH_MIN)
	btn.clip_text = false
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_slim_button_styles(btn)
	if unlocked:
		btn.text = "Selecionado" if selected else "Escolher"
		btn.disabled = selected
		btn.autowrap_mode = TextServer.AUTOWRAP_OFF
		btn.add_theme_font_size_override("font_size", CHOOSE_FONT)
		btn.pressed.connect(_on_choose.bind(def.id))
	else:
		btn.text = "🔒 %s" % def.lock_label()
		btn.disabled = true
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", LOCK_FONT)
	col.add_child(btn)
	return panel


func _apply_slim_button_styles(btn: Button) -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	for kind in ["normal", "hover", "pressed", "disabled", "focus"]:
		var src: StyleBox = btn.get_theme_stylebox(kind)
		if src == null and theme != null:
			src = theme.get_stylebox(kind, "Button")
		if src == null:
			continue
		var flat := src.duplicate() as StyleBoxFlat
		if flat == null:
			continue
		flat.content_margin_left = 8
		flat.content_margin_right = 8
		flat.content_margin_top = 8
		flat.content_margin_bottom = 8
		btn.add_theme_stylebox_override(kind, flat)


func _make_swatch(def: CharacterDef) -> ColorRect:
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(0, 36)
	swatch.color = def.accent
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return swatch


func _on_choose(character_id: String) -> void:
	if not Game.select_character(character_id):
		status_label.text = "Ainda bloqueado."
		return
	status_label.text = "Pronto. Esse caçador entra na próxima fase."
	call_deferred("_rebuild")


func _on_navigation_failed(_path: String) -> void:
	_navigating = false


func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	if not SceneRouter.to_hub():
		_navigating = false
