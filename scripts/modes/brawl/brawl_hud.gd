extends CanvasLayer
## HUD mínimo da batalha: HP dos dois caçadores, cronômetro, vitória.

var _p1: Node
var _p2: Node
var _p1_bar: ProgressBar
var _p2_bar: ProgressBar
var _p1_label: Label
var _p2_label: Label
var _time_label: Label
var _banner: Label
var _hint: Label


func _ready() -> void:
	layer = 20
	_build()


func bind_hunters(p1: Node, p2: Node) -> void:
	_p1 = p1
	_p2 = p2
	_refresh_hp()


func set_time_left(seconds: float) -> void:
	if _time_label == null:
		return
	var s: int = maxi(0, int(ceil(seconds)))
	_time_label.text = "%d:%02d" % [s / 60, s % 60]


func show_winner(text: String) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.visible = true
	if _hint:
		_hint.text = "Último de pé. F6 de novo pra repetir."


func _process(_delta: float) -> void:
	_refresh_hp()


func _refresh_hp() -> void:
	_apply_hp(_p1, _p1_bar, _p1_label)
	_apply_hp(_p2, _p2_bar, _p2_label)


func _apply_hp(pawn: Node, bar: ProgressBar, lab: Label) -> void:
	if pawn == null or not is_instance_valid(pawn) or bar == null or lab == null:
		return
	var cur: int = int(pawn.get("hp"))
	var mx: int = 100
	if pawn.has_method("get_max_hp"):
		mx = int(pawn.call("get_max_hp"))
	mx = maxi(mx, 1)
	bar.max_value = float(mx)
	bar.value = float(maxi(0, cur))
	var name: String = _hunter_name(pawn)
	lab.text = "%s  %d/%d" % [name, cur, mx]


func _hunter_name(pawn: Node) -> String:
	var id: String = str(pawn.get("applied_character_id"))
	var def: CharacterDef = CharacterCatalog.find(id)
	if def != null and def.display_name != "":
		return def.display_name
	if id == "inosuke":
		return "Inosuke"
	if id == "nezuko":
		return "Nezuko"
	return id.capitalize()


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 110.0
	top.add_theme_constant_override("margin_left", 20)
	top.add_theme_constant_override("margin_top", 14)
	top.add_theme_constant_override("margin_right", 20)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	top.add_child(row)

	_p1_bar = _make_hp_block(row)
	_p1_label = _p1_bar.get_meta("title") as Label

	_time_label = Label.new()
	_time_label.name = "TimeLabel"
	_time_label.custom_minimum_size = Vector2(120, 0)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 28)
	_time_label.add_theme_color_override("font_color", Palette.GOLD)
	_time_label.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	_time_label.add_theme_constant_override("shadow_offset_x", 1)
	_time_label.add_theme_constant_override("shadow_offset_y", 1)
	_time_label.text = "1:30"
	row.add_child(_time_label)

	_p2_bar = _make_hp_block(row)
	_p2_label = _p2_bar.get_meta("title") as Label

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 108.0
	_hint.offset_bottom = 136.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Palette.CREAM)
	_hint.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	_hint.text = "Stick anda no chão e sobe/desce · golpe acerta o outro caçador"
	root.add_child(_hint)

	_banner = Label.new()
	_banner.name = "WinnerBanner"
	_banner.visible = false
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -400.0
	_banner.offset_top = -40.0
	_banner.offset_right = 400.0
	_banner.offset_bottom = 40.0
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 42)
	_banner.add_theme_color_override("font_color", Palette.GOLD)
	_banner.add_theme_color_override("font_shadow_color", Palette.INK)
	_banner.add_theme_constant_override("shadow_offset_x", 2)
	_banner.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(_banner)


func _make_hp_block(row: HBoxContainer) -> ProgressBar:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Palette.CREAM)
	title.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	title.text = "Caçador"
	box.add_child(title)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.CRIMSON
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_right = 4
	fill.corner_radius_bottom_left = 4
	var bg := StyleBoxFlat.new()
	fill.content_margin_left = 0
	bg.bg_color = Palette.CRIMSON_DIM
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_right = 4
	bg.corner_radius_bottom_left = 4
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	box.add_child(bar)
	bar.set_meta("title", title)
	return bar
