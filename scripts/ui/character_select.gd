extends Control
## Tela PERSONAGENS — 14 do checklist. Locked recusa; unlocked grava o id atual.

@onready var grid: GridContainer = %Grid
@onready var status_label: Label = %StatusLabel
@onready var current_label: Label = %CurrentLabel

var _navigating: bool = false


func _ready() -> void:
	_rebuild()
	if not SceneRouter.navigation_failed.is_connected(_on_navigation_failed):
		SceneRouter.navigation_failed.connect(_on_navigation_failed)


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
	panel.custom_minimum_size = Vector2(0, 148)
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
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(0, 36)
	swatch.color = def.accent
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = def.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Palette.CREAM)
	col.add_child(name_lbl)

	var kit_lbl := Label.new()
	kit_lbl.text = "%s · %s" % [def.skill_1_name, def.skill_2_name]
	kit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kit_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kit_lbl.add_theme_font_size_override("font_size", 12)
	kit_lbl.add_theme_color_override("font_color", Palette.with_alpha(Palette.CREAM, 0.75))
	col.add_child(kit_lbl)

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_ALL
	if unlocked:
		btn.text = "Selecionado" if selected else "Escolher"
		btn.disabled = selected
		btn.pressed.connect(_on_choose.bind(def.id))
	else:
		btn.text = "🔒 %s" % def.lock_label()
		btn.disabled = true
	col.add_child(btn)
	return panel


func _on_choose(character_id: String) -> void:
	if is_instance_valid(Audio):
		Audio.play_sfx("ui_click")
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
	if is_instance_valid(Audio):
		Audio.play_sfx("ui_click")
	if not SceneRouter.to_hub():
		_navigating = false
