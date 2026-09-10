extends Control
## Gaveta direita do hub: lista de amigos + sala LAN. Começa fechada.
## Abre por cima do hub — sem change_scene / go_to.

enum View { LIST, HOST, JOIN, GUEST_WAIT }

const COL_MIN_WIDTH := 320.0
const DRAWER_W := 360.0
const TOUCH_MIN := 48.0
const SLIDE_SEC := 0.22

const _UiFont := preload("res://scripts/ui/ui_font.gd")

var _view: int = View.LIST
var _drawer_open: bool = false
var _list_box: VBoxContainer
var _host_box: VBoxContainer
var _join_box: VBoxContainer
var _wait_box: VBoxContainer
var _code_label: Label
var _status_label: Label
var _code_input: LineEdit
var _ip_box: VBoxContainer
var _ip_input: LineEdit
var _toast: Label
var _toast_tween: Tween
var _meio_input: LineEdit
var _scroll: ScrollContainer
var _backdrop: ColorRect
var _drawer: Control
var _slide: Tween


func _ready() -> void:
	_UiFont.ensure_theme_space()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_bind_session()
	_load_meio_field()
	_refresh_list()
	_set_drawer_open(false, true)
	call_deferred("_sync_rows_width")
	if is_instance_valid(LanSession) and LanSession.is_guest() and LanSession.has_peer():
		show_host_picks_stage()
	else:
		_show(View.LIST)


func is_drawer_open() -> bool:
	return _drawer_open


func open_drawer() -> void:
	_set_drawer_open(true, false)


func close_drawer() -> void:
	_set_drawer_open(false, false)


func toggle_drawer() -> void:
	_set_drawer_open(not _drawer_open, false)


func _set_drawer_open(want: bool, instant: bool) -> void:
	_drawer_open = want
	if _backdrop == null or _drawer == null:
		return
	if want:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
		_drawer.visible = true
		_backdrop.visible = true
	_layout_drawer(want, instant)
	if want:
		call_deferred("_sync_rows_width")
	elif instant:
		_apply_closed_filters()
	elif _slide != null and _slide.is_valid():
		if not _slide.finished.is_connected(_apply_closed_filters):
			_slide.finished.connect(_apply_closed_filters, CONNECT_ONE_SHOT)


func _apply_closed_filters() -> void:
	if _drawer_open:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _backdrop != null:
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _layout_drawer(p_open: bool, instant: bool) -> void:
	var target_left: float = (-DRAWER_W - 16.0) if p_open else 16.0
	var target_right: float = -16.0 if p_open else (DRAWER_W + 16.0)
	var target_a: float = 0.45 if p_open else 0.0
	if instant:
		if _slide != null and _slide.is_valid():
			_slide.kill()
		_drawer.offset_left = target_left
		_drawer.offset_right = target_right
		_backdrop.color.a = target_a
		return
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = create_tween().set_parallel(true)
	_slide.tween_property(_drawer, "offset_left", target_left, SLIDE_SEC) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(_drawer, "offset_right", target_right, SLIDE_SEC) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(_backdrop, "color:a", target_a, SLIDE_SEC)


func _on_backdrop_gui(event: InputEvent) -> void:
	if not _drawer_open:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close_drawer()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		close_drawer()


func _unhandled_input(event: InputEvent) -> void:
	if not _drawer_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close_drawer()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.gui_input.connect(_on_backdrop_gui)
	add_child(_backdrop)

	_drawer = Control.new()
	_drawer.anchor_left = 1.0
	_drawer.anchor_top = 0.0
	_drawer.anchor_right = 1.0
	_drawer.anchor_bottom = 1.0
	_drawer.offset_top = 12.0
	_drawer.offset_bottom = -12.0
	_drawer.offset_left = 16.0
	_drawer.offset_right = DRAWER_W + 16.0
	_drawer.custom_minimum_size.x = COL_MIN_WIDTH
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_drawer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.with_alpha(Palette.PANEL, 0.92)
	sb.border_color = Palette.with_alpha(Palette.GOLD, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	_drawer.add_child(panel)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var head := HBoxContainer.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_theme_constant_override("separation", 8)
	root.add_child(head)
	var title := Label.new()
	title.text = "AMIGOS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_color_override("font_color", Palette.CREAM)
	title.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.add_theme_font_size_override("font_size", 20)
	_fit_label(title, false)
	head.add_child(title)
	var fechar := _plate_btn("Fechar", close_drawer)
	fechar.size_flags_horizontal = Control.SIZE_SHRINK_END
	fechar.custom_minimum_size = Vector2(120, TOUCH_MIN)
	head.add_child(fechar)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 8)
	root.add_child(_list_box)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 72)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_box.add_child(_scroll)
	var rows := VBoxContainer.new()
	rows.name = "FriendRows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	_scroll.add_child(rows)
	_list_box.set_meta("rows", rows)
	_scroll.resized.connect(_sync_rows_width)
	_list_box.add_child(_plate_btn("Criar sala", _on_create_pressed))
	_list_box.add_child(_plate_btn("Entrar", _on_join_open_pressed))
	var meio_l := Label.new()
	meio_l.text = "Computador da sala"
	meio_l.add_theme_font_size_override("font_size", 15)
	meio_l.add_theme_color_override("font_color", Palette.CREAM)
	_fit_label(meio_l, false)
	_list_box.add_child(meio_l)
	_meio_input = LineEdit.new()
	_meio_input.placeholder_text = "vazio = só o Wi-Fi"
	_meio_input.max_length = 64
	_meio_input.custom_minimum_size = Vector2(0, TOUCH_MIN)
	_meio_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meio_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	_meio_input.text_changed.connect(_on_meio_typed)
	_list_box.add_child(_meio_input)
	var hint := Label.new()
	hint.text = "Wi-Fi da casa ou o PC da sala.\nSem VPN."
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Palette.with_alpha(Palette.CREAM, 0.85))
	_fit_label(hint, true)
	_list_box.add_child(hint)

	_host_box = VBoxContainer.new()
	_host_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host_box.add_theme_constant_override("separation", 10)
	root.add_child(_host_box)
	var sala := Label.new()
	sala.text = "Sala"
	sala.add_theme_font_size_override("font_size", 14)
	sala.add_theme_color_override("font_color", Palette.CREAM)
	_fit_label(sala, false)
	_host_box.add_child(sala)
	_code_label = Label.new()
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.add_theme_font_size_override("font_size", 36)
	_code_label.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	_code_label.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	_code_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_code_label.gui_input.connect(_on_code_gui)
	_fit_label(_code_label, false)
	_host_box.add_child(_code_label)
	_status_label = Label.new()
	_status_label.text = "Esperando amigo…"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Palette.CREAM)
	_fit_label(_status_label, true)
	_host_box.add_child(_status_label)
	_host_box.add_child(_plate_btn("Fechar sala", _on_close_room))

	_join_box = VBoxContainer.new()
	_join_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_box.add_theme_constant_override("separation", 8)
	root.add_child(_join_box)
	var code_l := Label.new()
	code_l.text = "Código da sala"
	code_l.add_theme_color_override("font_color", Palette.CREAM)
	_fit_label(code_l, false)
	_join_box.add_child(code_l)
	_code_input = LineEdit.new()
	_code_input.max_length = 6
	_code_input.placeholder_text = "K7H4MP"
	_code_input.custom_minimum_size = Vector2(0, TOUCH_MIN)
	_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_code_input.text_changed.connect(_on_code_typed)
	_join_box.add_child(_code_input)
	_join_box.add_child(_plate_btn("Entrar", _on_join_confirm))
	var ip_toggle := Button.new()
	ip_toggle.text = "Não achou? IP do anfitrião"
	ip_toggle.flat = true
	ip_toggle.clip_text = false
	ip_toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ip_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_toggle.custom_minimum_size = Vector2(0, TOUCH_MIN)
	ip_toggle.pressed.connect(func() -> void: _ip_box.visible = not _ip_box.visible)
	_join_box.add_child(ip_toggle)
	_ip_box = VBoxContainer.new()
	_ip_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_box.visible = false
	_ip_input = LineEdit.new()
	_ip_input.placeholder_text = "127.0.0.1"
	_ip_input.custom_minimum_size = Vector2(0, TOUCH_MIN)
	_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_box.add_child(_ip_input)
	_join_box.add_child(_ip_box)
	_join_box.add_child(_plate_btn("VOLTAR", _on_close_room))

	_wait_box = VBoxContainer.new()
	_wait_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wait_box.add_theme_constant_override("separation", 10)
	root.add_child(_wait_box)
	var wait_l := Label.new()
	wait_l.text = "O anfitrião escolhe a fase"
	wait_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wait_l.add_theme_font_size_override("font_size", 18)
	wait_l.add_theme_color_override("font_color", Palette.CREAM)
	_fit_label(wait_l, true)
	_wait_box.add_child(wait_l)
	_wait_box.add_child(_plate_btn("Sair da sala", _on_close_room))

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	_toast.add_theme_font_size_override("font_size", 14)
	_toast.modulate.a = 0.0
	_fit_label(_toast, true)
	root.add_child(_toast)


func _fit_label(l: Label, wrap: bool) -> void:
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = false
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF


func _sync_rows_width() -> void:
	if _scroll == null or not is_instance_valid(_scroll) or _list_box == null:
		return
	if not _list_box.has_meta("rows"):
		return
	var rows: VBoxContainer = _list_box.get_meta("rows") as VBoxContainer
	if rows == null:
		return
	var w: float = _scroll.size.x
	if w > 1.0:
		rows.custom_minimum_size.x = w


func _gold_sb(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _plate_btn(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.clip_text = false
	btn.custom_minimum_size = Vector2(0, TOUCH_MIN)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	var normal := _gold_sb(Palette.with_alpha(Palette.GOLD_DIM, 0.85), Palette.GOLD)
	var hover := _gold_sb(Palette.with_alpha(Palette.GOLD, 0.92), Palette.GOLD_BRIGHT)
	var pressed := _gold_sb(Palette.with_alpha(Palette.GOLD_DIM, 0.95), Palette.GOLD)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Palette.CREAM)
	btn.pressed.connect(cb)
	return btn


func _bind_session() -> void:
	if not is_instance_valid(LanSession):
		return
	if not LanSession.room_ready.is_connected(_on_room_ready):
		LanSession.room_ready.connect(_on_room_ready)
	if not LanSession.peer_joined.is_connected(_on_peer_joined):
		LanSession.peer_joined.connect(_on_peer_joined)
	if not LanSession.peer_left.is_connected(_on_peer_left):
		LanSession.peer_left.connect(_on_peer_left)
	if not LanSession.join_failed.is_connected(_on_join_failed):
		LanSession.join_failed.connect(_on_join_failed)
	if not LanSession.handshake_rejected.is_connected(_on_join_failed):
		LanSession.handshake_rejected.connect(_on_join_failed)
	if not LanSession.toast_requested.is_connected(show_toast):
		LanSession.toast_requested.connect(show_toast)
	if not LanSession.session_closed.is_connected(_on_session_closed):
		LanSession.session_closed.connect(_on_session_closed)
	if not Game.friends_changed.is_connected(_refresh_list):
		Game.friends_changed.connect(_refresh_list)


func _process(_delta: float) -> void:
	if _view != View.JOIN:
		return
	if not is_instance_valid(LanSession) or not LanSession.is_guest():
		return
	if LanSession.has_peer():
		_show(View.GUEST_WAIT)
		return
	if LanSession.join_wait_elapsed_ms() >= 2500:
		_ip_box.visible = true


func _show(v: int) -> void:
	_view = v
	_list_box.visible = v == View.LIST
	_host_box.visible = v == View.HOST
	_join_box.visible = v == View.JOIN
	_wait_box.visible = v == View.GUEST_WAIT


func _refresh_list() -> void:
	var rows: VBoxContainer = _list_box.get_meta("rows") as VBoxContainer
	if rows == null:
		return
	for c: Node in rows.get_children():
		c.queue_free()
	if Game.friends.is_empty():
		var empty := Label.new()
		empty.text = "Ninguém"
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Palette.CREAM)
		_fit_label(empty, false)
		rows.add_child(empty)
		_sync_rows_width()
		return
	for d in Game.friends:
		var name := str(d.get("name", ""))
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lbl := Label.new()
		lbl.text = "• " + name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl.add_theme_color_override("font_color", Palette.CREAM)
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		lbl.gui_input.connect(_make_call_handler(name))
		_fit_label(lbl, false)
		row.add_child(lbl)
		var rm := Button.new()
		rm.text = "x"
		rm.custom_minimum_size = Vector2(TOUCH_MIN, TOUCH_MIN)
		rm.focus_mode = Control.FOCUS_NONE
		rm.pressed.connect(_make_remove_handler(name))
		row.add_child(rm)
		rows.add_child(row)
	_sync_rows_width()


func _make_remove_handler(friend_name: String) -> Callable:
	return func() -> void:
		Game.remove_friend(friend_name)


func _make_call_handler(friend_name: String) -> Callable:
	return func(event: InputEvent) -> void:
		if not event.is_pressed():
			return
		if event is InputEventMouseButton:
			if (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
				return
		elif not (event is InputEventScreenTouch):
			return
		_on_call_friend(friend_name)


func _load_meio_field() -> void:
	if _meio_input == null or not is_instance_valid(LanSession):
		return
	_meio_input.text = LanSession.get_sala_meio()


func _on_meio_typed(t: String) -> void:
	if not is_instance_valid(LanSession):
		return
	var s := t.strip_edges()
	if s.is_empty():
		LanSession.set_sala_meio("")
		return
	if SalaMeioClient.parse_endpoint(s).is_empty():
		return
	LanSession.set_sala_meio(s)


func _apply_meio_now() -> void:
	if _meio_input == null or not is_instance_valid(LanSession):
		return
	var t := _meio_input.text.strip_edges()
	if t.is_empty():
		LanSession.set_sala_meio("")
		return
	if not LanSession.set_sala_meio(t):
		show_toast("Endereço inválido")
		LanSession.set_sala_meio("")


func _on_call_friend(friend_name: String) -> void:
	if is_instance_valid(LanSession):
		LanSession.call_friend(friend_name)


func _on_create_pressed() -> void:
	if not is_instance_valid(LanSession):
		return
	_apply_meio_now()
	var code := LanSession.host_room()
	if code.is_empty():
		return
	_code_label.text = code
	_status_label.text = "Esperando amigo…"
	_show(View.HOST)


func _on_join_open_pressed() -> void:
	_code_input.text = ""
	_ip_input.text = ""
	_ip_box.visible = false
	_show(View.JOIN)


func _on_code_typed(t: String) -> void:
	var n := RoomCode.normalize(t)
	if _code_input.text != n:
		_code_input.text = n
		_code_input.caret_column = n.length()


func _on_join_confirm() -> void:
	if not is_instance_valid(LanSession):
		return
	_apply_meio_now()
	var code := _code_input.text
	if not RoomCode.is_valid(code):
		show_toast("Código inválido")
		return
	if _ip_box.visible and not _ip_input.text.strip_edges().is_empty():
		LanSession.join_by_ip(_ip_input.text, code)
		return
	LanSession.join_room(code)


func _on_close_room() -> void:
	if is_instance_valid(LanSession):
		LanSession.close_session()
	_show(View.LIST)


func _on_room_ready(code: String) -> void:
	_code_label.text = code
	_status_label.text = "Esperando amigo…"
	_show(View.HOST)


func _on_peer_joined(_nick: String) -> void:
	_status_label.text = "Amigo entrou"
	if is_instance_valid(LanSession) and LanSession.is_guest():
		_show(View.GUEST_WAIT)
	_refresh_list()


func _on_peer_left() -> void:
	_status_label.text = "Esperando amigo…"


func _on_join_failed(reason: String) -> void:
	show_toast(reason)
	_show(View.JOIN)


func _on_session_closed() -> void:
	_show(View.LIST)
	_refresh_list()


func _on_code_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not _code_label.text.is_empty():
			DisplayServer.clipboard_set(_code_label.text)
			show_toast("Código copiado")


func show_host_picks_stage() -> void:
	open_drawer()
	show_toast("O anfitrião escolhe a fase")
	if is_instance_valid(LanSession) and LanSession.is_guest():
		_show(View.GUEST_WAIT)


func show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
