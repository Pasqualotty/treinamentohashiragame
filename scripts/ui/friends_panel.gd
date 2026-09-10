extends Control
## Coluna direita do hub: lista de amigos + sala LAN. Isolado do Ken Burns.

enum View { LIST, HOST, JOIN, GUEST_WAIT }

var _view: int = View.LIST
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_bind_session()
	_refresh_list()
	_show(View.LIST)


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.with_alpha(Palette.PANEL, 0.82)
	sb.border_color = Palette.with_alpha(Palette.GOLD, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := Label.new()
	title.text = "AMIGOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Palette.CREAM)
	title.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	title.add_theme_font_size_override("font_size", 20)
	root.add_child(title)

	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 8)
	root.add_child(_list_box)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 160)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.name = "FriendRows"
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	_list_box.set_meta("rows", rows)
	_list_box.add_child(_plate_btn("CRIAR SALA", _on_create_pressed))
	_list_box.add_child(_plate_btn("ENTRAR", _on_join_open_pressed))
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Mesmo Wi-Fi da casa, sem rede de convidado isolado."
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Palette.with_alpha(Palette.CREAM, 0.85))
	_list_box.add_child(hint)

	_host_box = VBoxContainer.new()
	_host_box.add_theme_constant_override("separation", 10)
	root.add_child(_host_box)
	var sala := Label.new()
	sala.text = "Sala"
	sala.add_theme_font_size_override("font_size", 14)
	sala.add_theme_color_override("font_color", Palette.CREAM)
	_host_box.add_child(sala)
	_code_label = Label.new()
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.add_theme_font_size_override("font_size", 36)
	_code_label.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	_code_label.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	_code_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_code_label.gui_input.connect(_on_code_gui)
	_host_box.add_child(_code_label)
	_status_label = Label.new()
	_status_label.text = "Esperando amigo…"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Palette.CREAM)
	_host_box.add_child(_status_label)
	_host_box.add_child(_plate_btn("FECHAR SALA", _on_close_room))

	_join_box = VBoxContainer.new()
	_join_box.add_theme_constant_override("separation", 8)
	root.add_child(_join_box)
	var code_l := Label.new()
	code_l.text = "Código da sala"
	code_l.add_theme_color_override("font_color", Palette.CREAM)
	_join_box.add_child(code_l)
	_code_input = LineEdit.new()
	_code_input.max_length = 6
	_code_input.placeholder_text = "K7H4MP"
	_code_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_code_input.text_changed.connect(_on_code_typed)
	_join_box.add_child(_code_input)
	_join_box.add_child(_plate_btn("ENTRAR", _on_join_confirm))
	var ip_toggle := Button.new()
	ip_toggle.text = "Não achou? IP do anfitrião"
	ip_toggle.flat = true
	ip_toggle.pressed.connect(func() -> void: _ip_box.visible = not _ip_box.visible)
	_join_box.add_child(ip_toggle)
	_ip_box = VBoxContainer.new()
	_ip_box.visible = false
	_ip_input = LineEdit.new()
	_ip_input.placeholder_text = "127.0.0.1"
	_ip_box.add_child(_ip_input)
	_join_box.add_child(_ip_box)
	_join_box.add_child(_plate_btn("VOLTAR", func() -> void: _show(View.LIST)))

	_wait_box = VBoxContainer.new()
	_wait_box.add_theme_constant_override("separation", 10)
	root.add_child(_wait_box)
	var wait_l := Label.new()
	wait_l.text = "O anfitrião escolhe a fase"
	wait_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wait_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wait_l.add_theme_font_size_override("font_size", 18)
	wait_l.add_theme_color_override("font_color", Palette.CREAM)
	_wait_box.add_child(wait_l)
	_wait_box.add_child(_plate_btn("SAIR DA SALA", _on_close_room))

	_toast = Label.new()
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	_toast.add_theme_font_size_override("font_size", 14)
	_toast.modulate.a = 0.0
	root.add_child(_toast)


func _plate_btn(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 48)
	btn.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.with_alpha(Palette.GOLD_DIM, 0.85)
	sb.border_color = Palette.GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", sb)
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
		empty.text = "Ninguém ainda. Joguem uma sala juntos."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Palette.CREAM)
		rows.add_child(empty)
		return
	for d in Game.friends:
		var name := str(d.get("name", ""))
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "• " + name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", Palette.CREAM)
		row.add_child(lbl)
		var rm := Button.new()
		rm.text = "x"
		rm.custom_minimum_size = Vector2(36, 36)
		rm.focus_mode = Control.FOCUS_NONE
		rm.pressed.connect(func() -> void: Game.remove_friend(name))
		row.add_child(rm)
		rows.add_child(row)


func _on_create_pressed() -> void:
	if not is_instance_valid(LanSession):
		return
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
