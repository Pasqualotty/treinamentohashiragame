extends Control
## Lobby da sala em tela cheia: equipe, showcase e faixa de caçadores.
## Layout tipo menu de espera (centro + laterais). Arte própria — sem copiar IP.

signal leave_pressed
signal start_pressed
signal mode_pressed(mode_id: int)
signal invite_pressed(friend_name: String)
signal copy_code_pressed
signal toast_requested(text: String)

const TOUCH_MIN := 48.0
const PORTRAIT := 64.0
const PARTY_W := 236.0
const MODE_W := 252.0
const IDLE_FRAME := 0

const _UiFont := preload("res://scripts/ui/ui_font.gd")

var _code_label: Label
var _status_label: Label
var _name_label: Label
var _mode_hint: Label
var _showcase: TextureRect
var _party_box: VBoxContainer
var _strip: HBoxContainer
var _mode_box: VBoxContainer
var _mode_btns: Dictionary = {}
var _start_btn: Button
var _leave_btn: Button
var _trophy_label: Label
var _invite_layer: Control
var _invite_rows: VBoxContainer
var _idle_tex: Texture2D
var _refresh_queued: bool = false


func _ready() -> void:
	_UiFont.ensure_theme_space()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_bind()
	refresh()


func queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_flush_refresh")


func _flush_refresh() -> void:
	_refresh_queued = false
	refresh()


func refresh() -> void:
	if _code_label == null:
		return
	var code := ""
	if is_instance_valid(LanSession):
		code = str(LanSession.room_code)
	_code_label.text = code if not code.is_empty() else "————"
	_refresh_status()
	_sync_mode_buttons()
	_sync_start()
	_refresh_party()
	_refresh_strip()
	_refresh_showcase()
	_refresh_invite_rows()
	_refresh_trophies()
	if _leave_btn != null:
		_leave_btn.text = "Sair da sala" if _is_guest() else "Fechar sala"
	if _mode_box != null:
		_mode_box.visible = _is_host()
	if _mode_hint != null:
		_mode_hint.visible = not _is_host()
		if _mode_hint.visible and is_instance_valid(LanSession):
			_mode_hint.text = "Modo: %s\nO anfitrião escolhe o modo e começa." % GameMode.label_of(int(LanSession.game_mode))


func _bind() -> void:
	if is_instance_valid(LanSession):
		if LanSession.has_signal("roster_changed") and not LanSession.roster_changed.is_connected(queue_refresh):
			LanSession.roster_changed.connect(queue_refresh)
		if not LanSession.peer_joined.is_connected(_on_peer):
			LanSession.peer_joined.connect(_on_peer)
		if not LanSession.peer_left.is_connected(queue_refresh):
			LanSession.peer_left.connect(queue_refresh)
		if LanSession.has_signal("mode_changed") and not LanSession.mode_changed.is_connected(_on_mode):
			LanSession.mode_changed.connect(_on_mode)
	if is_instance_valid(Game):
		if Game.has_signal("character_changed") and not Game.character_changed.is_connected(_on_char):
			Game.character_changed.connect(_on_char)
		if Game.has_signal("friends_changed") and not Game.friends_changed.is_connected(queue_refresh):
			Game.friends_changed.connect(queue_refresh)
		if Game.has_signal("trophies_changed") and not Game.trophies_changed.is_connected(_on_trophies):
			Game.trophies_changed.connect(_on_trophies)


func _on_peer(_nick: String) -> void:
	queue_refresh()


func _on_mode(_mode_id: int) -> void:
	queue_refresh()


func _on_char(_id: String) -> void:
	queue_refresh()


func _on_trophies(_total: int) -> void:
	_refresh_trophies()


func _refresh_trophies() -> void:
	if _trophy_label == null:
		return
	var n: int = 0
	if is_instance_valid(Game) and Game.has_method("get_mp_trophies"):
		n = int(Game.call("get_mp_trophies"))
	if n <= 0:
		_trophy_label.text = "Troféus · 0"
	else:
		_trophy_label.text = "Troféus · %d" % n


func _is_host() -> bool:
	return is_instance_valid(LanSession) and LanSession.is_host()


func _is_guest() -> bool:
	return is_instance_valid(LanSession) and LanSession.is_guest()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.with_alpha(Palette.INK, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 16)
	root.add_theme_constant_override("margin_right", 16)
	root.add_theme_constant_override("margin_top", 12)
	root.add_theme_constant_override("margin_bottom", 12)
	add_child(root)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)

	col.add_child(_build_top())

	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	col.add_child(body)
	body.add_child(_build_party())
	body.add_child(_build_center())
	body.add_child(_build_modes())

	col.add_child(_build_strip())

	_invite_layer = _build_invite()
	add_child(_invite_layer)
	_invite_layer.visible = false


func _build_top() -> Control:
	var bar := HBoxContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_constant_override("separation", 10)

	var sala := Label.new()
	sala.text = "Sala"
	sala.add_theme_font_size_override("font_size", 16)
	sala.add_theme_color_override("font_color", Palette.CREAM)
	_fit(sala, false)
	bar.add_child(sala)

	_code_label = Label.new()
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_code_label.add_theme_font_size_override("font_size", 36)
	_code_label.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	_code_label.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	_code_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_code_label.gui_input.connect(_on_code_gui)
	_fit(_code_label, false)
	bar.add_child(_code_label)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Palette.CREAM)
	_fit(_status_label, true)
	bar.add_child(_status_label)

	_trophy_label = Label.new()
	_trophy_label.name = "TrophyLabel"
	_trophy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_trophy_label.add_theme_font_size_override("font_size", 16)
	_trophy_label.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	_trophy_label.add_theme_color_override("font_shadow_color", Palette.SHADOW)
	_fit(_trophy_label, false)
	bar.add_child(_trophy_label)

	_leave_btn = _plate("Fechar sala", func() -> void:
		leave_pressed.emit()
	)
	_leave_btn.custom_minimum_size = Vector2(168, TOUCH_MIN)
	_leave_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	bar.add_child(_leave_btn)
	return bar


func _build_party() -> Control:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size.x = PARTY_W
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Equipe"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	_fit(title, false)
	wrap.add_child(title)

	_party_box = VBoxContainer.new()
	_party_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_box.add_theme_constant_override("separation", 6)
	wrap.add_child(_party_box)

	var plus := _plate("+ Chamar amigo", _open_invite)
	plus.name = "InvitePlus"
	plus.custom_minimum_size = Vector2(0, TOUCH_MIN)
	wrap.add_child(plus)
	return wrap


func _build_center() -> Control:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 6)

	_showcase = TextureRect.new()
	_showcase.name = "LobbyShowcase"
	_showcase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_showcase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_showcase.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_showcase.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_showcase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(_showcase)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Palette.CREAM)
	_fit(_name_label, false)
	wrap.add_child(_name_label)
	return wrap


func _build_modes() -> Control:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size.x = MODE_W
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 8)

	_mode_box = VBoxContainer.new()
	_mode_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_box.add_theme_constant_override("separation", 6)
	wrap.add_child(_mode_box)

	var ml := Label.new()
	ml.text = "Modo"
	ml.add_theme_font_size_override("font_size", 16)
	ml.add_theme_color_override("font_color", Palette.CREAM)
	_fit(ml, false)
	_mode_box.add_child(ml)

	for mid in GameMode.all_ids():
		var mb := _plate(GameMode.label_of(mid), _make_mode(mid))
		mb.set_meta("mode_id", mid)
		_mode_btns[mid] = mb
		_mode_box.add_child(mb)

	_start_btn = _plate("Começar", func() -> void:
		start_pressed.emit()
	)
	_start_btn.visible = false
	_mode_box.add_child(_start_btn)

	_mode_hint = Label.new()
	_mode_hint.visible = false
	_mode_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_hint.add_theme_font_size_override("font_size", 16)
	_mode_hint.add_theme_color_override("font_color", Palette.CREAM)
	_fit(_mode_hint, true)
	wrap.add_child(_mode_hint)
	return wrap


func _build_strip() -> Control:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 4)

	var hint := Label.new()
	hint.text = "Escolhe o caçador"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Palette.CREAM)
	_fit(hint, false)
	wrap.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, PORTRAIT + 20.0)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	wrap.add_child(scroll)

	_strip = HBoxContainer.new()
	_strip.name = "CharStrip"
	_strip.add_theme_constant_override("separation", 8)
	scroll.add_child(_strip)
	return wrap


func _build_invite() -> Control:
	var layer := Control.new()
	layer.name = "InviteOverlay"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_close_invite()
		elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			_close_invite()
	)
	layer.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 16.0
	panel.offset_top = 16.0
	panel.offset_right = 16.0 + 320.0
	panel.offset_bottom = -16.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PANEL
	sb.border_color = Palette.with_alpha(Palette.GOLD, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var t := Label.new()
	t.text = "Chamar amigo"
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	_fit(t, false)
	col.add_child(t)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_invite_rows = VBoxContainer.new()
	_invite_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_invite_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_invite_rows)

	col.add_child(_plate("Voltar", _close_invite))
	return layer


func _open_invite() -> void:
	if not _is_host():
		toast_requested.emit("Só o anfitrião chama")
		return
	if not is_instance_valid(LanSession) or str(LanSession.room_code).is_empty():
		toast_requested.emit("Cria a sala primeiro")
		return
	_invite_layer.visible = true
	_refresh_invite_rows()


func _close_invite() -> void:
	if _invite_layer != null:
		_invite_layer.visible = false


func _refresh_invite_rows() -> void:
	if _invite_rows == null:
		return
	_clear_box(_invite_rows)
	if not is_instance_valid(Game) or Game.friends.is_empty():
		var empty := Label.new()
		empty.text = "Ninguém na lista ainda"
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Palette.with_alpha(Palette.CREAM, 0.85))
		_fit(empty, true)
		_invite_rows.add_child(empty)
		return
	for d in Game.friends:
		var name := str(d.get("name", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var lbl := Label.new()
		lbl.text = name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", Palette.CREAM)
		_fit(lbl, false)
		row.add_child(lbl)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(TOUCH_MIN, TOUCH_MIN)
		plus.focus_mode = Control.FOCUS_NONE
		plus.pressed.connect(_make_invite(name))
		row.add_child(plus)
		_invite_rows.add_child(row)


func _make_invite(friend_name: String) -> Callable:
	return func() -> void:
		invite_pressed.emit(friend_name)
		_close_invite()


func _make_mode(mode_id: int) -> Callable:
	return func() -> void:
		mode_pressed.emit(mode_id)


func _refresh_status() -> void:
	if _status_label == null or not is_instance_valid(LanSession):
		return
	if _is_guest():
		if LanSession.has_peer():
			_status_label.text = "Escolhe o caçador. O anfitrião começa."
		else:
			_status_label.text = "Entrando na sala…"
		return
	if not LanSession.is_host():
		return
	var mode_id: int = int(LanSession.game_mode)
	if GameMode.max_clients_for(mode_id) > 1:
		var n: int = LanSession.hunter_count() if LanSession.has_peer() else 1
		var cap: int = GameMode.hunter_cap(mode_id)
		if GameMode.is_vs_oni(mode_id):
			_status_label.text = "Caçadores %d/%d · Começar vai ao mapa" % [n, cap]
		else:
			_status_label.text = "Caçadores %d/%d · Começar quando quiser" % [n, cap]
	elif GameMode.is_vs_oni(mode_id):
		_status_label.text = "Começar para escolher a fase"
	elif not GameMode.scene_path(mode_id).is_empty():
		_status_label.text = "Começar quando quiser"
	elif LanSession.has_peer():
		_status_label.text = "Amigo entrou"
	else:
		_status_label.text = "Esperando amigo…"


func _sync_start() -> void:
	if _start_btn == null:
		return
	var mid: int = GameMode.Id.VS_ONI_2
	if is_instance_valid(LanSession):
		mid = int(LanSession.game_mode)
	var path := GameMode.scene_path(mid)
	var oni: bool = GameMode.is_vs_oni(mid)
	_start_btn.visible = _is_host() and (oni or (not path.is_empty() and ResourceLoader.exists(path)))


func _sync_mode_buttons() -> void:
	var current: int = GameMode.Id.VS_ONI_2
	if is_instance_valid(LanSession):
		current = int(LanSession.game_mode)
	for mid in _mode_btns.keys():
		var btn: Button = _mode_btns[mid] as Button
		if btn == null:
			continue
		var selected: bool = int(mid) == current
		var bg: Color = Palette.with_alpha(Palette.GOLD, 0.95) if selected else Palette.with_alpha(Palette.GOLD_DIM, 0.85)
		var border: Color = Palette.GOLD_BRIGHT if selected else Palette.GOLD
		btn.add_theme_stylebox_override("normal", _gold_sb(bg, border))
		btn.disabled = not _is_host()


func _refresh_party() -> void:
	if _party_box == null:
		return
	_clear_box(_party_box)
	var cap := 2
	if is_instance_valid(LanSession):
		cap = GameMode.hunter_cap(int(LanSession.game_mode))
	var filled: Dictionary = {}
	var roster: Array = []
	if is_instance_valid(LanSession):
		roster = LanSession.get_roster()
	for item in roster:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec := item as Dictionary
		var slot := int(rec.get("slot", 0))
		filled[slot] = rec
	for slot in range(cap):
		_party_box.add_child(_party_slot(slot, filled.get(slot, null)))


func _party_slot(slot: int, rec: Variant) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, TOUCH_MIN)
	row.add_theme_constant_override("separation", 8)
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(40, 40)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(face)
	var txt := VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(txt)
	var nick := Label.new()
	nick.add_theme_font_size_override("font_size", 15)
	nick.add_theme_color_override("font_color", Palette.CREAM)
	_fit(nick, false)
	txt.add_child(nick)
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Palette.with_alpha(Palette.CREAM, 0.8))
	_fit(sub, false)
	txt.add_child(sub)
	if typeof(rec) != TYPE_DICTIONARY:
		nick.text = "Vazio"
		sub.text = "Esperando"
		return row
	var d := rec as Dictionary
	var char_id := _slot_char(slot, str(d.get("char_id", "tanjiro")))
	var def: CharacterDef = CharacterCatalog.find(char_id)
	if def != null and def.has_portrait_art():
		face.texture = _load_tex(def.portrait_path)
	nick.text = str(d.get("nick", "Caçador"))
	var you := _is_local_slot(slot)
	sub.text = "Você · %s" % (def.display_name if def != null else char_id) if you else (def.display_name if def != null else char_id)
	return row


func _is_local_slot(slot: int) -> bool:
	if _is_host():
		return slot == 0
	if _is_guest() and is_instance_valid(LanSession):
		return slot == int(LanSession.local_coop_slot)
	return false


func _slot_char(slot: int, from_roster: String) -> String:
	if _is_local_slot(slot) and is_instance_valid(Game):
		return str(Game.current_character_id)
	return from_roster


func _refresh_strip() -> void:
	if _strip == null or not is_instance_valid(Game):
		return
	_clear_box(_strip)
	var current := str(Game.current_character_id)
	var any := false
	for def: CharacterDef in CharacterCatalog.load_all():
		if not Game.is_character_unlocked(def.id):
			continue
		any = true
		_strip.add_child(_char_btn(def, def.id == current))
	if not any:
		var empty := Label.new()
		empty.text = "Nenhum caçador liberado"
		empty.add_theme_color_override("font_color", Palette.CREAM)
		_fit(empty, false)
		_strip.add_child(empty)
		return
	var more := Label.new()
	more.text = "Mais em PERSONAGENS"
	more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	more.add_theme_font_size_override("font_size", 13)
	more.add_theme_color_override("font_color", Palette.with_alpha(Palette.CREAM, 0.75))
	_fit(more, false)
	_strip.add_child(more)


func _char_btn(def: CharacterDef, selected: bool) -> Button:
	var btn := Button.new()
	btn.name = "PickChar_%s" % def.id
	btn.text = def.display_name
	btn.custom_minimum_size = Vector2(96, TOUCH_MIN + 16.0)
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_text = true
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bg: Color = Palette.with_alpha(Palette.GOLD, 0.95) if selected else Palette.with_alpha(Palette.PANEL, 0.96)
	var border: Color = Palette.GOLD_BRIGHT if selected else Palette.with_alpha(Palette.GOLD, 0.45)
	btn.add_theme_stylebox_override("normal", _gold_sb(bg, border))
	btn.add_theme_stylebox_override("hover", _gold_sb(Palette.with_alpha(Palette.GOLD, 0.88), Palette.GOLD_BRIGHT))
	btn.add_theme_stylebox_override("pressed", _gold_sb(Palette.with_alpha(Palette.GOLD_DIM, 0.95), Palette.GOLD))
	btn.add_theme_color_override("font_color", Palette.CREAM)
	btn.add_theme_font_size_override("font_size", 13)
	if def.has_portrait_art():
		var tex := _load_tex(def.portrait_path)
		if tex != null:
			btn.icon = tex
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var cid := def.id
	btn.pressed.connect(func() -> void:
		_pick(cid)
	)
	return btn


func _pick(character_id: String) -> void:
	if not is_instance_valid(LanSession) or not LanSession.has_method("pick_character"):
		if is_instance_valid(Game):
			Game.select_character(character_id)
		return
	if not bool(LanSession.pick_character(character_id)):
		toast_requested.emit("Esse caçador ainda não liberou")
		return
	queue_refresh()


func _refresh_showcase() -> void:
	if _showcase == null or not is_instance_valid(Game):
		return
	var def: CharacterDef = CharacterCatalog.find(str(Game.current_character_id))
	if def == null:
		def = CharacterCatalog.starter()
	_name_label.text = def.display_name if def != null else "Caçador"
	_idle_tex = null
	if def != null and def.hub_frames_dir != "":
		_idle_tex = _load_tex("%s/%02d.png" % [def.hub_frames_dir.rstrip("/"), IDLE_FRAME])
	if _idle_tex == null and def != null and def.has_portrait_art():
		_idle_tex = _load_tex(def.portrait_path)
	_showcase.texture = _idle_tex


func _on_code_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		copy_code_pressed.emit()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		copy_code_pressed.emit()


func _fit(l: Label, wrap: bool) -> void:
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = false
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF


func _gold_sb(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _plate(text: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.clip_text = false
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.custom_minimum_size = Vector2(0, TOUCH_MIN)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _gold_sb(Palette.with_alpha(Palette.GOLD_DIM, 0.85), Palette.GOLD))
	btn.add_theme_stylebox_override("hover", _gold_sb(Palette.with_alpha(Palette.GOLD, 0.92), Palette.GOLD_BRIGHT))
	btn.add_theme_stylebox_override("pressed", _gold_sb(Palette.with_alpha(Palette.GOLD_DIM, 0.95), Palette.GOLD))
	btn.add_theme_color_override("font_color", Palette.CREAM)
	btn.pressed.connect(cb)
	return btn


func _clear_box(box: Node) -> void:
	if box == null:
		return
	for c: Node in box.get_children():
		box.remove_child(c)
		c.free()


func _load_tex(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null
