extends CanvasLayer
## Barras de luta (verde/amarelo/vermelho) + respiração + tela final.

const HP_GREEN := Color(0.22, 0.82, 0.32, 1.0)
const HP_YELLOW := Color(0.95, 0.82, 0.18, 1.0)
const HP_ORANGE := Color(0.96, 0.48, 0.12, 1.0)
const HP_RED := Color(0.86, 0.16, 0.16, 1.0)
const TRACK := Color(0.06, 0.06, 0.08, 0.92)

var _hunters: Array[Node] = []
var _bars: Array[ProgressBar] = []
var _breaths: Array[ProgressBar] = []
var _names: Array[Label] = []
var _time_label: Label
var _overlay: Control
var _banner: Label
var on_rematch: Callable
var on_leave: Callable


func _ready() -> void:
	layer = 20
	_build()


func bind_hunters(hunters: Array) -> void:
	_hunters.clear()
	for n: Variant in hunters:
		if n is Node:
			_hunters.append(n as Node)
	_refresh()


func set_time_left(seconds: float) -> void:
	if _time_label == null:
		return
	var s: int = maxi(0, int(ceil(seconds)))
	_time_label.text = "%d:%02d" % [s / 60, s % 60]


func show_winner(text: String) -> void:
	if _banner:
		_banner.text = text
	if _overlay:
		_overlay.visible = true


func has_exit_actions() -> bool:
	return _overlay != null and _overlay.visible


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	var visual_to_slot: Array[int] = [0, 2, 1, 3]
	var i: int = 0
	while i < _bars.size():
		var slot: int = visual_to_slot[i] if i < visual_to_slot.size() else i
		var pawn: Node = _hunters[slot] if slot < _hunters.size() else null
		_apply(pawn, i)
		i += 1


func _apply(pawn: Node, idx: int) -> void:
	if idx >= _bars.size():
		return
	var bar: ProgressBar = _bars[idx]
	var breath: ProgressBar = _breaths[idx]
	var lab: Label = _names[idx]
	if pawn == null or not is_instance_valid(pawn):
		bar.get_parent().visible = false
		return
	bar.get_parent().visible = true
	var cur: int = int(pawn.get("hp"))
	var mx: int = 100
	if pawn.has_method("get_max_hp"):
		mx = maxi(int(pawn.call("get_max_hp")), 1)
	bar.max_value = float(mx)
	bar.value = float(maxi(0, cur))
	_paint_hp(bar, float(cur) / float(mx))
	lab.text = "%s  %d/%d" % [_hunter_name(pawn), cur, mx]
	var bcur: float = 0.0
	var bmax: float = 100.0
	if pawn.has_method("get_pawn_breath"):
		bcur = float(pawn.call("get_pawn_breath"))
		bmax = maxf(float(pawn.call("get_pawn_breath_max")), 1.0)
	breath.max_value = bmax
	breath.value = bcur
	var bfill := breath.get_theme_stylebox("fill") as StyleBoxFlat
	if bfill:
		bfill.bg_color = Palette.WATER_BRIGHT if bcur >= bmax else Palette.WATER


func _paint_hp(bar: ProgressBar, ratio: float) -> void:
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill == null:
		return
	if ratio > 0.66:
		fill.bg_color = HP_GREEN
	elif ratio > 0.4:
		fill.bg_color = HP_YELLOW
	elif ratio > 0.2:
		fill.bg_color = HP_ORANGE
	else:
		fill.bg_color = HP_RED


func _hunter_name(pawn: Node) -> String:
	var id: String = str(pawn.get("applied_character_id"))
	var def: CharacterDef = CharacterCatalog.find(id)
	if def != null and def.display_name != "":
		return def.display_name
	return id.capitalize()


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 168.0
	top.add_theme_constant_override("margin_left", 16)
	top.add_theme_constant_override("margin_top", 10)
	top.add_theme_constant_override("margin_right", 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	top.add_child(cols)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	_add_fighter_block(left)
	_add_fighter_block(left)

	_time_label = Label.new()
	_time_label.custom_minimum_size = Vector2(110, 0)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 30)
	_time_label.add_theme_color_override("font_color", Palette.GOLD)
	_time_label.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	_time_label.add_theme_constant_override("shadow_offset_x", 2)
	_time_label.add_theme_constant_override("shadow_offset_y", 2)
	_time_label.text = "1:30"
	cols.add_child(_time_label)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	_add_fighter_block(right)
	_add_fighter_block(right)

	var hint := Label.new()
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 168.0
	hint.offset_bottom = 192.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Palette.CREAM)
	hint.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	hint.text = "Anda no chão · skills enchem a respiração · pads de vida / haste"
	root.add_child(hint)

	_overlay = Control.new()
	_overlay.name = "EndOverlay"
	_overlay.visible = false
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_overlay)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -220.0
	box.offset_top = -130.0
	box.offset_right = 220.0
	box.offset_bottom = 160.0
	box.add_theme_constant_override("separation", 14)
	_overlay.add_child(box)
	_banner = Label.new()
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 40)
	_banner.add_theme_color_override("font_color", Palette.GOLD)
	_banner.add_theme_color_override("font_shadow_color", Palette.INK)
	_banner.add_theme_constant_override("shadow_offset_x", 2)
	_banner.add_theme_constant_override("shadow_offset_y", 2)
	_banner.text = "Fim"
	box.add_child(_banner)
	box.add_child(_end_btn("De novo", _on_rematch))
	box.add_child(_end_btn("Sair", _on_leave))


func _add_fighter_block(col: VBoxContainer) -> void:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	col.add_child(wrap)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Palette.CREAM)
	title.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	title.text = "Caçador"
	wrap.add_child(title)
	var hp := _bar(26.0, HP_GREEN)
	wrap.add_child(hp)
	var breath := _bar(10.0, Palette.WATER)
	wrap.add_child(breath)
	_bars.append(hp)
	_breaths.append(breath)
	_names.append(title)
	wrap.visible = false


func _bar(height: float, fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(5)
	fill.content_margin_left = 0
	var bg := StyleBoxFlat.new()
	bg.bg_color = TRACK
	bg.set_corner_radius_all(5)
	bg.border_width_left = 2
	bg.border_width_top = 2
	bg.border_width_right = 2
	bg.border_width_bottom = 2
	bg.border_color = Palette.GOLD_DIM
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	return bar


func _end_btn(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 56)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.with_alpha(Palette.GOLD, 0.95)
	sb.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Palette.INK)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(cb)
	return btn


func _on_rematch() -> void:
	if on_rematch.is_valid():
		on_rematch.call()


func _on_leave() -> void:
	if on_leave.is_valid():
		on_leave.call()
