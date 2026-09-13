extends Control
## Gaveta direita do hub: lista de amigos + sala LAN. Começa fechada.
## Abre por cima do hub — sem change_scene / go_to.

enum View { LIST, HOST, JOIN, GUEST_WAIT, ADD_FRIEND }

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
var _add_box: VBoxContainer
var _code_label: Label
var _status_label: Label
var _code_input: LineEdit
var _friend_input: LineEdit
var _my_code_label: Label
var _host_invite_box: VBoxContainer
var _toast: Label
var _toast_tween: Tween
var _scroll: ScrollContainer
var _backdrop: ColorRect
var _drawer: Control
var _slide: Tween
var _mode_btns: Dictionary = {}
var _mode_label: Label
var _start_btn: Button
var _lobby: Control


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
	_refresh_list()
	_set_drawer_open(false, true)
	call_deferred("_sync_rows_width")
	if is_instance_valid(LanSession) and LanSession.is_guest() and LanSession.has_peer():
		show_host_picks_stage()
	else:
		_show(View.LIST)


func is_drawer_open() -> bool:
	return _drawer_open


func open_drawer(instant: bool = false) -> void:
	_set_drawer_open(true, instant)


func close_drawer(instant: bool = false) -> void:
	if _is_lobby_on():
		return
	_set_drawer_open(false, instant)


func get_drawer_global_rect() -> Rect2:
	if _is_lobby_on():
		return get_global_rect()
	if _drawer == null or not is_instance_valid(_drawer):
		return Rect2()
	return _drawer.get_global_rect()


func is_lobby_open() -> bool:
	return _is_lobby_on()


func toggle_drawer() -> void:
	if _is_lobby_on():
		return
	_set_drawer_open(not _drawer_open, false)


func _is_lobby_on() -> bool:
	return _lobby != null and is_instance_valid(_lobby) and _lobby.visible


func _set_drawer_open(want: bool, instant: bool) -> void:
	_drawer_open = want
	if _backdrop == null or _drawer == null:
		return
	if _is_lobby_on():
		mouse_filter = Control.MOUSE_FILTER_STOP
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_backdrop.visible = false
		_drawer.visible = false
		_set_play_visible(false)
		return
	if want:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
		_drawer.visible = true
		_backdrop.visible = true
		_set_play_visible(false)
	_layout_drawer(want, instant)
	if want:
		call_deferred("_sync_rows_width")
	elif instant:
		_apply_closed_filters()
	elif _slide != null and _slide.is_valid():
		if not _slide.finished.is_connected(_apply_closed_filters):
			_slide.finished.connect(_apply_closed_filters, CONNECT_ONE_SHOT)


func _apply_closed_filters() -> void:
	if _drawer_open or _is_lobby_on():
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _backdrop != null:
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_play_visible(true)


func _hub_play_button() -> Button:
	var hub := get_parent()
	if hub == null:
		return null
	return hub.get_node_or_null("%PlayButton") as Button


func _set_play_visible(p_visible: bool) -> void:
	var btn := _hub_play_button()
	if btn != null:
		btn.visible = p_visible


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
	if _is_lobby_on():
		return
	if not _drawer_open:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close_drawer()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		close_drawer()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if _is_lobby_on():
			_on_close_room()
			get_viewport().set_input_as_handled()
			return
		if not _drawer_open:
			return
		close_drawer()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.gui_input.connect(_on_backdrop_gui)
	add_child(_backdrop)

	_drawer = PanelContainer.new()
	_drawer.custom_minimum_size.x = COL_MIN_WIDTH
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PANEL
	sb.border_color = Palette.with_alpha(Palette.GOLD, 0.55)
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_right = 0
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	_drawer.add_theme_stylebox_override("panel", sb)
	add_child(_drawer)
	_drawer.anchor_left = 1.0
	_drawer.anchor_top = 0.0
	_drawer.anchor_right = 1.0
	_drawer.anchor_bottom = 1.0
	_drawer.offset_top = 0.0
	_drawer.offset_bottom = 0.0
	_drawer.offset_left = 16.0
	_drawer.offset_right = DRAWER_W + 16.0

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	_drawer.add_child(root)

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
	_refresh_my_code()
	_list_box.add_child(_plate_btn("Adicionar amigo", _on_add_open_pressed))
	_list_box.add_child(_plate_btn("Criar sala", _on_create_pressed))
	_list_box.add_child(_plate_btn("Entrar", _on_join_open_pressed))
	var hint := Label.new()
	hint.text = "Escreve o nome dele.\nEle aceita. Depois o + chama pra sala."
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Palette.with_alpha(Palette.CREAM, 0.85))
	_fit_label(hint, true)
	_list_box.add_child(hint)

	_host_box = VBoxContainer.new()
	_host_box.visible = false
	_host_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_host_box)

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
	_join_box.add_child(_plate_btn("VOLTAR", _on_close_room))

	_add_box = VBoxContainer.new()
	_add_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_box.add_theme_constant_override("separation", 8)
	root.add_child(_add_box)
	var add_l := Label.new()
	add_l.text = "Nome do amigo"
	add_l.add_theme_color_override("font_color", Palette.CREAM)
	_fit_label(add_l, false)
	_add_box.add_child(add_l)
	_friend_input = LineEdit.new()
	_friend_input.max_length = Game.MAX_PLAYER_NAME_LEN
	_friend_input.placeholder_text = "como no perfil"
	_friend_input.custom_minimum_size = Vector2(0, TOUCH_MIN)
	_friend_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friend_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_friend_input.text_changed.connect(_on_friend_name_typed)
	_add_box.add_child(_friend_input)
	_add_box.add_child(_plate_btn("Enviar convite", _on_friend_invite_confirm))
	_add_box.add_child(_plate_btn("VOLTAR", _on_add_back))

	_wait_box = VBoxContainer.new()
	_wait_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wait_box.add_theme_constant_override("separation", 10)
	root.add_child(_wait_box)
	var wait_l := Label.new()
	wait_l.text = "O anfitrião escolhe o modo"
	wait_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wait_l.add_theme_font_size_override("font_size", 18)
	wait_l.add_theme_color_override("font_color", Palette.CREAM)
	_fit_label(wait_l, true)
	_wait_box.add_child(wait_l)
	_wait_box.add_child(_plate_btn("Sair da sala", _on_close_room))

	_lobby = preload("res://scripts/ui/mp_lobby.gd").new()
	_lobby.name = "MpLobby"
	_lobby.visible = false
	if _lobby.has_signal("leave_pressed"):
		_lobby.leave_pressed.connect(_on_close_room)
	if _lobby.has_signal("start_pressed"):
		_lobby.start_pressed.connect(_on_start_pressed)
	if _lobby.has_signal("mode_pressed"):
		_lobby.mode_pressed.connect(_on_mode_pressed)
	if _lobby.has_signal("invite_pressed"):
		_lobby.invite_pressed.connect(_on_call_friend)
	if _lobby.has_signal("copy_code_pressed"):
		_lobby.copy_code_pressed.connect(_on_copy_room_code)
	if _lobby.has_signal("toast_requested"):
		_lobby.toast_requested.connect(show_toast)
	add_child(_lobby)

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.anchor_left = 0.1
	_toast.anchor_right = 0.9
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_top = -72.0
	_toast.offset_bottom = -24.0
	_toast.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	_toast.add_theme_font_size_override("font_size", 16)
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit_label(_toast, true)
	add_child(_toast)


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
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	if LanSession.has_signal("mode_changed") and not LanSession.mode_changed.is_connected(_on_mode_changed):
		LanSession.mode_changed.connect(_on_mode_changed)
	if not Game.friends_changed.is_connected(_refresh_list):
		Game.friends_changed.connect(_refresh_list)
	if Game.has_signal("friend_invites_changed") and not Game.friend_invites_changed.is_connected(_refresh_list):
		Game.friend_invites_changed.connect(_refresh_list)
	if LanSession.has_signal("room_invite_received") and not LanSession.room_invite_received.is_connected(_on_room_invite):
		LanSession.room_invite_received.connect(_on_room_invite)
	if LanSession.has_signal("roster_changed") and not LanSession.roster_changed.is_connected(_on_roster_changed):
		LanSession.roster_changed.connect(_on_roster_changed)


func _process(_delta: float) -> void:
	if _view != View.JOIN:
		return
	if not is_instance_valid(LanSession) or not LanSession.is_guest():
		return
	if LanSession.has_peer():
		_show(View.GUEST_WAIT)


func _show(v: int) -> void:
	_view = v
	var room := v == View.HOST or v == View.GUEST_WAIT
	_list_box.visible = v == View.LIST
	_host_box.visible = false
	_join_box.visible = v == View.JOIN
	_wait_box.visible = false
	if _add_box != null:
		_add_box.visible = v == View.ADD_FRIEND
	if _lobby != null:
		_lobby.visible = room
		if room and _lobby.has_method("refresh"):
			_lobby.call("refresh")
	if room:
		_set_drawer_open(true, true)
	elif _drawer_open:
		_set_drawer_open(true, true)
	if v == View.LIST:
		_refresh_my_code()
		_refresh_list()


func _refresh_my_code() -> void:
	if is_instance_valid(Game) and Game.has_method("ensure_friend_code"):
		Game.ensure_friend_code()


func _refresh_list() -> void:
	if _list_box == null or not _list_box.has_meta("rows"):
		return
	var rows: VBoxContainer = _list_box.get_meta("rows") as VBoxContainer
	if rows == null:
		return
	for c: Node in rows.get_children():
		c.queue_free()
	_refresh_my_code()
	var has_pending: bool = not Game.pending_in.is_empty() or not Game.pending_out.is_empty()
	if not Game.pending_in.is_empty():
		var pend_l := Label.new()
		pend_l.text = "Convites"
		pend_l.add_theme_font_size_override("font_size", 14)
		pend_l.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
		_fit_label(pend_l, false)
		rows.add_child(pend_l)
		for d in Game.pending_in:
			rows.add_child(_pending_row(str(d.get("name", "Caçador")), str(d.get("friend_id", ""))))
	if not Game.pending_out.is_empty():
		for d in Game.pending_out:
			var wait := Label.new()
			wait.text = "Aguardando %s…" % str(d.get("name", "amigo"))
			wait.add_theme_font_size_override("font_size", 14)
			wait.add_theme_color_override("font_color", Palette.with_alpha(Palette.CREAM, 0.85))
			_fit_label(wait, true)
			rows.add_child(wait)
	if Game.friends.is_empty() and not has_pending:
		var empty := Label.new()
		empty.text = "Ninguém"
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Palette.CREAM)
		_fit_label(empty, false)
		rows.add_child(empty)
		_sync_rows_width()
		_refresh_host_invites()
		return
	for d in Game.friends:
		var name := str(d.get("name", ""))
		rows.add_child(_friend_row(name, true))
	_sync_rows_width()
	_refresh_host_invites()


func _pending_row(friend_name: String, friend_id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.text = friend_name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.add_theme_color_override("font_color", Palette.CREAM)
	_fit_label(lbl, false)
	row.add_child(lbl)
	var ok := _plate_btn("Aceitar", func() -> void:
		if is_instance_valid(LanSession):
			LanSession.accept_friend_invite(friend_id)
	)
	ok.custom_minimum_size = Vector2(96, TOUCH_MIN)
	row.add_child(ok)
	var no := _plate_btn("Não", func() -> void:
		if is_instance_valid(LanSession):
			LanSession.decline_friend_invite(friend_id)
	)
	no.custom_minimum_size = Vector2(72, TOUCH_MIN)
	row.add_child(no)
	return row


func _friend_row(friend_name: String, with_remove: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.text = "• " + friend_name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.add_theme_color_override("font_color", Palette.CREAM)
	_fit_label(lbl, false)
	row.add_child(lbl)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(TOUCH_MIN, TOUCH_MIN)
	plus.focus_mode = Control.FOCUS_NONE
	plus.pressed.connect(_make_invite_handler(friend_name))
	row.add_child(plus)
	if with_remove:
		var rm := Button.new()
		rm.text = "x"
		rm.custom_minimum_size = Vector2(TOUCH_MIN, TOUCH_MIN)
		rm.focus_mode = Control.FOCUS_NONE
		rm.pressed.connect(_make_remove_handler(friend_name))
		row.add_child(rm)
	return row


func _refresh_host_invites() -> void:
	if _lobby != null and _lobby.visible and _lobby.has_method("refresh"):
		_lobby.call("refresh")


func _make_remove_handler(friend_name: String) -> Callable:
	return func() -> void:
		Game.remove_friend(friend_name)


func _make_invite_handler(friend_name: String) -> Callable:
	return func() -> void:
		_on_call_friend(friend_name)


func _on_call_friend(friend_name: String) -> void:
	if is_instance_valid(LanSession):
		LanSession.invite_friend_to_room(friend_name)


func _on_add_open_pressed() -> void:
	if _friend_input != null:
		_friend_input.text = ""
	_show(View.ADD_FRIEND)


func _on_add_back() -> void:
	_show(View.LIST)


func _on_friend_name_typed(t: String) -> void:
	var n := Game.sanitize_player_name(t)
	if _friend_input == null:
		return
	if _friend_input.text != n:
		_friend_input.text = n
		_friend_input.caret_column = n.length()


func _on_friend_invite_confirm() -> void:
	if not is_instance_valid(LanSession) or _friend_input == null:
		return
	LanSession.send_friend_invite(_friend_input.text)


func _on_my_code_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _my_code_label != null and not _my_code_label.text.is_empty():
			DisplayServer.clipboard_set(_my_code_label.text)
			show_toast("Código copiado")
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		if _my_code_label != null and not _my_code_label.text.is_empty():
			DisplayServer.clipboard_set(_my_code_label.text)
			show_toast("Código copiado")


func _on_room_invite(from_nick: String, code: String) -> void:
	open_drawer()
	if _code_input != null:
		_code_input.text = RoomCode.normalize(code)
	if is_instance_valid(LanSession) and LanSession.is_host():
		show_toast("%s te chamou" % from_nick)
		return
	if is_instance_valid(LanSession) and LanSession.is_guest() and LanSession.has_peer():
		return
	show_toast("%s te chamou pra sala" % from_nick)
	if is_instance_valid(LanSession):
		LanSession.join_room(code)
	_show(View.JOIN)


func _on_create_pressed() -> void:
	if not is_instance_valid(LanSession):
		return
	var code := LanSession.host_room()
	if code.is_empty():
		return
	_show(View.HOST)


func _make_mode_handler(mode_id: int) -> Callable:
	return func() -> void:
		_on_mode_pressed(mode_id)


func _on_mode_pressed(mode_id: int) -> void:
	if not is_instance_valid(LanSession) or not LanSession.is_host():
		return
	LanSession.set_game_mode(mode_id)
	_refresh_lobby()


func _on_mode_changed(_mode_id: int) -> void:
	_refresh_lobby()


func _on_roster_changed() -> void:
	_refresh_lobby()


func _refresh_lobby() -> void:
	if _lobby == null or not _lobby.visible:
		return
	if _lobby.has_method("queue_refresh"):
		_lobby.call("queue_refresh")
	elif _lobby.has_method("refresh"):
		_lobby.call_deferred("refresh")


func _on_copy_room_code() -> void:
	if not is_instance_valid(LanSession):
		return
	var code := str(LanSession.room_code)
	if code.is_empty():
		return
	DisplayServer.clipboard_set(code)
	show_toast("Código copiado")


func _on_start_pressed() -> void:
	if not is_instance_valid(LanSession) or not LanSession.is_host():
		return
	if not LanSession.has_method("start_selected_mode"):
		return
	LanSession.start_selected_mode()


func _sync_start_btn() -> void:
	_refresh_lobby()


func _sync_mode_buttons() -> void:
	_refresh_lobby()


func _refresh_host_status() -> void:
	_refresh_lobby()


func _on_join_open_pressed() -> void:
	_code_input.text = ""
	_show(View.JOIN)


func _on_code_typed(t: String) -> void:
	var n := RoomCode.normalize(t)
	if _code_input.text != n:
		_code_input.text = n
		_code_input.caret_column = n.length()


func _on_join_confirm() -> void:
	if not is_instance_valid(LanSession):
		return
	var code := _code_input.text
	if not RoomCode.is_valid(code):
		show_toast("Código inválido")
		return
	LanSession.join_room(code)


func _on_close_room() -> void:
	if is_instance_valid(LanSession):
		LanSession.close_session()
	_show(View.LIST)


func _on_room_ready(_code: String) -> void:
	_show(View.HOST)


func _on_peer_joined(_nick: String) -> void:
	_refresh_lobby()
	if is_instance_valid(LanSession) and LanSession.is_guest():
		_show(View.GUEST_WAIT)
	_refresh_list()


func _on_peer_left() -> void:
	_refresh_lobby()


func _on_join_failed(reason: String) -> void:
	show_toast(reason)
	_show(View.JOIN)


func _on_session_closed() -> void:
	_show(View.LIST)
	_refresh_list()


func _on_code_gui(event: InputEvent) -> void:
	if _code_label == null:
		return
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
