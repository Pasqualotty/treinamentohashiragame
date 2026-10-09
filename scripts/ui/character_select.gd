extends Control
## Tela PERSONAGENS — 15 do catálogo. Locked recusa; unlocked grava o id atual.
## Layout 1280×720: 3 colunas, wrap por palavra, Hub fora do scroll.
## O viewport só mostra N cards completos — nunca uma faixa de olhos.

const TOUCH_MIN := 48.0
const CARD_CONTENT_MIN := 236.0
const PORTRAIT_MIN_H := 96.0
const KIT_FONT := 12
const CHOOSE_FONT := 16
const LOCK_FONT := 13
const PEEK_GUARD_PX := 2.0

const _UiFont := preload("res://scripts/ui/ui_font.gd")

@onready var grid: GridContainer = %Grid
@onready var status_label: Label = %StatusLabel
@onready var current_label: Label = %CurrentLabel
@onready var scroll: ScrollContainer = %Scroll

var _navigating: bool = false
var _applied_card_h: float = CARD_CONTENT_MIN
var _fitting: bool = false
var _choosing: bool = false


func _ready() -> void:
	SafeInset.apply(self)
	_UiFont.ensure_theme_space()
	_lock_header_wrap()
	_style_bottom_bar()
	MetaChrome.setup_screen(self, "characters", get_node_or_null("%Title") as Label,
		status_label, get_node_or_null("%BackButton") as Button)
	if not resized.is_connected(_on_root_resized):
		resized.connect(_on_root_resized)
	if not scroll.resized.is_connected(_on_root_resized):
		scroll.resized.connect(_on_root_resized)
	_rebuild()
	await get_tree().process_frame
	_fit_cards()
	if not SceneRouter.navigation_failed.is_connected(_on_navigation_failed):
		SceneRouter.navigation_failed.connect(_on_navigation_failed)


func _lock_header_wrap() -> void:
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.clip_contents = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var title := get_node_or_null("%Title") as Label
	if title != null:
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.clip_text = false
	current_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	current_label.clip_text = false
	current_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.clip_text = false
	var back := get_node_or_null("%BackButton") as Button
	if back != null:
		back.autowrap_mode = TextServer.AUTOWRAP_OFF
		back.clip_text = false
		back.custom_minimum_size = Vector2(168, TOUCH_MIN)
		back.add_theme_font_size_override("font_size", 18)


func _style_bottom_bar() -> void:
	var bar := get_node_or_null("Root/Col/BottomBar") as PanelContainer
	if bar == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.with_alpha(Palette.NIGHT_BG, 0.0)
	style.set_corner_radius_all(0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 8
	style.content_margin_bottom = 0
	bar.add_theme_stylebox_override("panel", style)


func _on_root_resized() -> void:
	call_deferred("_fit_cards")


func _fit_cards() -> void:
	if _fitting:
		return
	var want: float = _card_height_for_viewport()
	if is_equal_approx(want, _applied_card_h) and grid.get_child_count() > 0:
		return
	_fitting = true
	_applied_card_h = want
	_rebuild()
	_fitting = false


func _card_height_for_viewport() -> float:
	var avail: float = scroll.size.y
	if avail < 80.0:
		return CARD_CONTENT_MIN
	var sep: float = float(grid.get_theme_constant("v_separation"))
	var n: int = 1
	while n < 5:
		var next_n: int = n + 1
		var need: float = float(next_n) * CARD_CONTENT_MIN + float(next_n - 1) * sep
		if need > avail + 0.5:
			break
		n = next_n
	# Inteiro: N fileiras cabem inteiras; a próxima começa abaixo do clip.
	var inner: int = int(floor(avail - PEEK_GUARD_PX)) - (n - 1) * int(sep)
	var card_h: float = float(maxi(int(CARD_CONTENT_MIN), inner / n))
	return card_h


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
	panel.custom_minimum_size = Vector2(0, _applied_card_h)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := _card_style(def, selected)
	panel.add_theme_stylebox_override("panel", style)
	if selected:
		_pulse_border(panel, style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	if def.has_portrait_art():
		var face_tex: Texture2D = load(def.portrait_path) as Texture2D
		if face_tex != null:
			var face := TextureRect.new()
			face.texture = _bust_atlas(face_tex)
			face.custom_minimum_size = Vector2(0, PORTRAIT_MIN_H)
			face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			face.size_flags_vertical = Control.SIZE_EXPAND_FILL
			face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_finish_portrait(face, unlocked)
			col.add_child(face)
		else:
			col.add_child(_finish_portrait(_make_swatch(def), unlocked))
	else:
		col.add_child(_finish_portrait(_make_swatch(def), unlocked))

	var name_lbl := Label.new()
	name_lbl.text = def.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_lbl.clip_text = false
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Palette.CREAM)
	col.add_child(name_lbl)

	var kit_lbl := Label.new()
	kit_lbl.text = "%s · %s" % [def.skill_1_name, def.skill_2_name]
	kit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kit_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kit_lbl.clip_text = false
	kit_lbl.max_lines_visible = 2
	kit_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	kit_lbl.add_theme_font_size_override("font_size", KIT_FONT)
	kit_lbl.add_theme_color_override("font_color", Palette.with_alpha(Palette.CREAM, 0.75))
	col.add_child(kit_lbl)

	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_ALL
	btn.custom_minimum_size = Vector2(0, TOUCH_MIN)
	btn.clip_text = false
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_apply_slim_button_styles(btn)
	if unlocked:
		btn.text = "Selecionado" if selected else "Escolher"
		btn.disabled = selected
		btn.autowrap_mode = TextServer.AUTOWRAP_OFF
		btn.add_theme_font_size_override("font_size", CHOOSE_FONT)
		btn.pressed.connect(_on_choose.bind(def.id, panel, style))
	else:
		btn.text = "🔒 %s" % def.lock_label()
		btn.disabled = true
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.add_theme_font_size_override("font_size", LOCK_FONT)
	UiMotion.press_bounce(btn)
	col.add_child(btn)
	return panel


func _card_style(def: CharacterDef, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.with_alpha(Palette.PANEL, 0.94)
	style.border_color = Palette.GOLD if selected else Palette.with_alpha(def.accent, 0.7)
	style.set_border_width_all(3 if selected else 2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


## Borda do card selecionado respira entre ouro e ouro claro (devagar, em loop).
func _pulse_border(panel: Control, style: StyleBoxFlat) -> void:
	var tw: Tween = panel.create_tween().set_loops()
	tw.tween_property(style, "border_color", Palette.GOLD_BRIGHT, 1.1) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(style, "border_color", Palette.GOLD_DIM, 1.1) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Retrato trancado: dessaturado (cinza 0.55, só no retrato) + chip 🔒.
func _finish_portrait(face: Control, unlocked: bool) -> Control:
	if unlocked:
		return face
	face.self_modulate = Color(0.55, 0.55, 0.55, 1.0)
	var chip := PanelContainer.new()
	chip.name = "LockChip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Palette.with_alpha(Palette.PANEL, 0.95)
	chip_style.border_color = Palette.with_alpha(Palette.GOLD, 0.45)
	chip_style.set_border_width_all(1)
	chip_style.set_corner_radius_all(12)
	chip_style.content_margin_left = 8
	chip_style.content_margin_right = 8
	chip_style.content_margin_top = 2
	chip_style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", chip_style)
	var lock := Label.new()
	lock.text = "🔒"
	lock.add_theme_font_size_override("font_size", 14)
	chip.add_child(lock)
	chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chip.offset_top = 4.0
	chip.offset_right = -4.0
	face.add_child(chip)
	return face


## Recorte cabeça/busto com margem — não o corpo inteiro nem uma faixa de olhos.
func _bust_atlas(src: Texture2D) -> Texture2D:
	var sz: Vector2 = src.get_size()
	if sz.x < 8.0 or sz.y < 8.0:
		return src
	var atlas := AtlasTexture.new()
	atlas.atlas = src
	atlas.filter_clip = true
	atlas.region = Rect2(sz.x * 0.10, sz.y * 0.00, sz.x * 0.80, sz.y * 0.62)
	return atlas


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


## Toque num card livre: pop + borda acende, e só então confirma a escolha.
func _on_choose(character_id: String, card: Control = null, style: StyleBoxFlat = null) -> void:
	if _choosing:
		return
	_choosing = true
	if style != null:
		style.border_color = Palette.GOLD_BRIGHT
		style.set_border_width_all(4)
	UiMotion.pop(card, 1.06)
	await get_tree().create_timer(0.16).timeout
	_choosing = false
	if not is_inside_tree():
		return
	_confirm_choice(character_id)


func _confirm_choice(character_id: String) -> void:
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
