extends SceneTree
## Smoke LAN: RoomCode, friends no save, hub %FriendsPanel, host_room+close.
## Nunca escreve em user://save.json.
## Uso: godot --headless --path . -s res://scripts/qa/smoke_lan_friends.gd

const TEMP_SAVE := "user://smoke_lan_friends.json"
const HUB := "res://scenes/main_menu/hub.tscn"

var _ok: bool = true
var _messages: Array[String] = []
var _game: Node = null
var _temp_active: bool = false
var _orig_name: String = ""
var _orig_coins: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	_ok = false
	_messages.append("FAIL: " + msg)


func _pass(msg: String) -> void:
	_messages.append("ok: " + msg)


func _run() -> void:
	_game = root.get_node_or_null("Game")
	if _game == null:
		_fail("autoload Game ausente")
		_finish()
		return
	var lan: Node = root.get_node_or_null("LanSession")
	if lan == null:
		_fail("autoload LanSession ausente")
		_finish()
		return
	_use_temp_save()
	_test_room_code()
	_test_friends_save()
	_test_legacy_without_friends()
	await _test_hub_panel()
	_test_host_close(lan)
	await _test_join_voltar(lan)
	_test_host_leave_keeps_room(lan)
	await _test_guest_clears_packed(lan)
	_test_boot_never_conectando()
	_test_max_clients(lan)
	_test_game_mode_contract()
	await _test_mode_options()
	_test_mode_doors(lan)
	await _test_four_hunters(lan)
	_test_meio_parse()
	_test_meio_self_test()
	_test_meio_pc_off(lan)
	_test_meio_not_in_friends_save(lan)
	await _test_hub_computador_field()
	await _test_call_name_not_x()
	_test_meio_two_process(lan)
	_finish()


func _use_temp_save() -> void:
	_orig_name = str(_game.get("player_name"))
	_orig_coins = int(_game.get("coins_banked"))
	_game.call("set_save_path", TEMP_SAVE)
	_temp_active = true
	_wipe(TEMP_SAVE)
	AtomicJson.remove_sidecars(TEMP_SAVE)
	_game.set("friends", [])
	_game.set("coins_banked", 10)
	_game.set("player_name", "HostSmoke")
	_game.call("save_game")


func _restore() -> void:
	if not _temp_active:
		return
	_temp_active = false
	_wipe(TEMP_SAVE)
	AtomicJson.remove_sidecars(TEMP_SAVE)
	if _game == null:
		return
	_game.call("set_save_path", "")
	_game.set("player_name", _orig_name)
	_game.set("coins_banked", _orig_coins)
	_game.call("load_game")


func _wipe(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_room_code() -> void:
	var code: String = str(RoomCode.generate())
	if code.length() != 6:
		_fail("RoomCode length=%d" % code.length())
		return
	if not RoomCode.is_valid(code):
		_fail("generate() não passou is_valid: %s" % code)
		return
	if RoomCode.is_valid("O0I1AB"):
		_fail("aceitou O/0/I/1")
		return
	if RoomCode.is_valid("abc12i"):
		_fail("aceitou i minúsculo após normalize")
		return
	var n: String = str(RoomCode.normalize(" k7h4mp "))
	if n != "K7H4MP":
		_fail("normalize = %s" % n)
		return
	if not RoomCode.is_valid(n):
		_fail("K7H4MP deveria ser válido")
		return
	_pass("RoomCode gera 6 e rejeita O/0/I/1")


func _test_friends_save() -> void:
	if not bool(_game.call("add_friend", "Sobrinho")):
		_fail("add_friend Sobrinho")
		return
	if not bool(_game.call("add_friend", "Sobrinho")):
		_fail("upsert mesmo nome")
		return
	var friends: Array = _game.get("friends")
	if friends.size() != 1:
		_fail("upsert duplicou: %d" % friends.size())
		return
	if str(friends[0].get("name", "")).find("ip") >= 0:
		_fail("nome contém ip")
		return
	if not bool(_game.call("add_friend", char(0x200B))):
		pass
	else:
		_fail("nome invisível aceito")
		return
	for i in 20:
		_game.call("add_friend", "Amigo%d" % i)
	friends = _game.get("friends")
	if friends.size() > 16:
		_fail("cap 16 furado: %d" % friends.size())
		return
	_game.call("save_game")
	_game.set("friends", [])
	_game.call("load_game")
	friends = _game.get("friends")
	if friends.is_empty():
		_fail("reload perdeu friends")
		return
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEMP_SAVE))
	if typeof(payload) != TYPE_DICTIONARY:
		_fail("save JSON inválido")
		return
	var txt: String = JSON.stringify(payload)
	if txt.contains("\"ip\"") or txt.contains("17777"):
		_fail("save tem IP/porta")
		return
	if int(payload.get("version", 0)) != 1:
		_fail("SAVE_VERSION mudou")
		return
	_pass("friends save/reload/cap 16 sem IP")


func _test_legacy_without_friends() -> void:
	_wipe(TEMP_SAVE)
	AtomicJson.remove_sidecars(TEMP_SAVE)
	var f := FileAccess.open(TEMP_SAVE, FileAccess.WRITE)
	f.store_string('{"version":1,"coins_banked":44,"player_name":"Muichiro","current_character_id":"tanjiro","stages_cleared":[],"upgrades":{}}')
	f.close()
	_game.call("load_game")
	if int(_game.get("coins_banked")) != 44:
		_fail("legado coins=%s" % _game.get("coins_banked"))
		return
	var friends: Array = _game.get("friends")
	if not friends.is_empty():
		_fail("legado sem chave friends não veio vazio")
		return
	_pass("save legado sem friends = []")


func _open_drawer(fp: Node) -> void:
	if fp != null and fp.has_method("open_drawer"):
		fp.call("open_drawer", true)


func _space_px(c: Control) -> float:
	var font: Font = c.get_theme_font("font")
	var size: int = c.get_theme_font_size("font_size")
	if font == null:
		return 0.0
	var with_sp: float = font.get_string_size("a a", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var no_sp: float = font.get_string_size("aa", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return with_sp - no_sp


func _test_hub_panel() -> void:
	var packed: PackedScene = load(HUB) as PackedScene
	if packed == null:
		_fail("hub.tscn não carrega")
		return
	var inst: Node = packed.instantiate()
	if inst == null:
		_fail("hub instantiate null")
		return
	root.add_child(inst)
	for i in range(10):
		await process_frame
	var amigos: Button = inst.get_node_or_null("%FriendsButton") as Button
	if amigos == null or amigos.text != "AMIGOS":
		_fail("hub sem botão AMIGOS")
		inst.queue_free()
		await process_frame
		return
	if amigos.size.y < 44.0 or amigos.size.x < 200.0:
		_fail("AMIGOS toque baixo: %s" % amigos.size)
		inst.queue_free()
		await process_frame
		return
	var fp: Node = inst.get_node_or_null("%FriendsPanel")
	if fp == null:
		_fail("hub sem %FriendsPanel")
		inst.queue_free()
		await process_frame
		return
	if fp.has_method("is_drawer_open") and bool(fp.call("is_drawer_open")):
		_fail("gaveta já aberta no hub")
		inst.queue_free()
		await process_frame
		return
	_open_drawer(fp)
	for i in range(8):
		await process_frame
	if fp.has_method("is_drawer_open") and not bool(fp.call("is_drawer_open")):
		_fail("open_drawer não abriu a gaveta")
		inst.queue_free()
		await process_frame
		return
	if _find_label(fp, "Computador da sala") == null:
		_fail("FriendsPanel sem campo Computador da sala")
		inst.queue_free()
		await process_frame
		return
	var empty: Label = _find_label(fp, "Ninguém")
	if empty == null:
		_fail("empty state sem Ninguém")
		inst.queue_free()
		await process_frame
		return
	if empty.autowrap_mode != TextServer.AUTOWRAP_OFF:
		_fail("Ninguém com autowrap (cai na vertical)")
		inst.queue_free()
		await process_frame
		return
	if empty.get_line_count() > 1 or empty.get_combined_minimum_size().x < 48.0:
		_fail("Ninguém ilegível lines=%d min=%s size=%s" % [empty.get_line_count(), empty.get_combined_minimum_size(), empty.size])
		inst.queue_free()
		await process_frame
		return
	var criar: Button = _find_button(fp, "Criar sala")
	if criar == null or not criar.text.contains(" "):
		_fail("sem botão Criar sala com espaço")
		inst.queue_free()
		await process_frame
		return
	if criar.size.y < 44.0:
		_fail("Criar sala toque baixo: %.0f" % criar.size.y)
		inst.queue_free()
		await process_frame
		return
	if _space_px(criar) < 3.0:
		_fail("Criar sala: U+0020 advance=%.2f" % _space_px(criar))
		inst.queue_free()
		await process_frame
		return
	var hint: Label = inst.find_child("MapHint", true, false) as Label
	if hint == null:
		_fail("hub sem MapHint")
		inst.queue_free()
		await process_frame
		return
	if _space_px(hint) < 3.0:
		_fail("MapHint: U+0020 advance=%.2f" % _space_px(hint))
		inst.queue_free()
		await process_frame
		return
	if _find_button(fp, "Entrar") == null:
		_fail("sem botão Entrar")
		inst.queue_free()
		await process_frame
		return
	if _find_label(fp, "Wi-Fi da casa ou o PC da sala.\nSem VPN.") == null:
		_fail("dica Sem VPN sumiu ou quebrou")
		inst.queue_free()
		await process_frame
		return
	if _find_button(fp, "Fechar") == null:
		_fail("gaveta sem Fechar")
		inst.queue_free()
		await process_frame
		return
	if not fp.has_method("get_drawer_global_rect"):
		_fail("FriendsPanel sem get_drawer_global_rect")
		inst.queue_free()
		await process_frame
		return
	var drect: Rect2 = fp.call("get_drawer_global_rect")
	var vp: Vector2 = inst.get_viewport_rect().size
	if drect.size.y < vp.y - 8.0:
		_fail("gaveta não vai do topo até embaixo: %s vp=%s" % [drect, vp])
		inst.queue_free()
		await process_frame
		return
	var play: Button = inst.get_node_or_null("%PlayButton") as Button
	if play == null:
		_fail("hub sem PlayButton")
		inst.queue_free()
		await process_frame
		return
	if play.visible:
		var overlap: Rect2 = drect.intersection(play.get_global_rect())
		if overlap.size.x > 4.0 and overlap.size.y > 4.0:
			_fail("JOGAR fura a gaveta overlap=%s" % overlap)
			inst.queue_free()
			await process_frame
			return
	var hint_lan: Label = _find_label(fp, "Wi-Fi da casa ou o PC da sala.\nSem VPN.")
	if hint_lan != null and play.visible:
		var h_over: Rect2 = hint_lan.get_global_rect().intersection(play.get_global_rect())
		if h_over.size.x > 4.0 and h_over.size.y > 4.0:
			_fail("dica senta no JOGAR overlap=%s" % h_over)
			inst.queue_free()
			await process_frame
			return
	if fp.has_method("close_drawer"):
		fp.call("close_drawer", true)
		for i in range(4):
			await process_frame
		if play.visible == false:
			_fail("JOGAR não voltou ao fechar a gaveta")
			inst.queue_free()
			await process_frame
			return
		# reabre — o close abaixo é o teste de close_drawer animado/API
		_open_drawer(fp)
		for i in range(4):
			await process_frame
	if fp.has_method("close_drawer"):
		fp.call("close_drawer")
		for i in range(6):
			await process_frame
		if bool(fp.call("is_drawer_open")):
			_fail("close_drawer não fechou")
			inst.queue_free()
			await process_frame
			return
	inst.queue_free()
	await process_frame
	_pass("hub botão AMIGOS + gaveta + espaço U+0020")


func _test_host_close(lan: Node) -> void:
	var code: String = str(lan.call("host_room"))
	if code.is_empty() or not RoomCode.is_valid(code):
		_fail("host_room code=%s" % code)
		lan.call("close_session")
		return
	if not bool(lan.call("is_host")):
		_fail("host_room não marcou host")
		lan.call("close_session")
		return
	var peer: MultiplayerPeer = lan.multiplayer.multiplayer_peer
	if peer == null:
		_fail("host sem multiplayer_peer")
		lan.call("close_session")
		return
	lan.call("close_session")
	if lan.multiplayer.multiplayer_peer != null:
		_fail("close_session deixou peer vivo")
		return
	if bool(lan.call("is_host")) or bool(lan.call("in_session")):
		_fail("close_session não zerou role")
		return
	_pass("host_room + close_session sem crash")


func _find_label(n: Node, text: String) -> Label:
	if n is Label and (n as Label).text == text:
		return n as Label
	for c: Node in n.get_children():
		var hit: Label = _find_label(c, text)
		if hit != null:
			return hit
	return null


func _find_line_placeholder(n: Node, needle: String) -> LineEdit:
	if n is LineEdit and (n as LineEdit).placeholder_text.find(needle) >= 0:
		return n as LineEdit
	for c: Node in n.get_children():
		var hit: LineEdit = _find_line_placeholder(c, needle)
		if hit != null:
			return hit
	return null


func _find_friend_remove_btn(n: Node, friend_name: String) -> Button:
	if n.name == "FriendRows":
		for row: Node in n.get_children():
			if row.is_queued_for_deletion():
				continue
			var match_name := false
			var xbtn: Button = null
			for c: Node in row.get_children():
				if c is Label and str((c as Label).text).contains(friend_name):
					match_name = true
				if c is Button and (c as Button).text == "x":
					xbtn = c as Button
			if match_name:
				return xbtn
	for c: Node in n.get_children():
		var hit: Button = _find_friend_remove_btn(c, friend_name)
		if hit != null:
			return hit
	return null


func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n as Button
	for c: Node in n.get_children():
		var hit: Button = _find_button(c, text)
		if hit != null:
			return hit
	return null


func _test_join_voltar(lan: Node) -> void:
	var packed: PackedScene = load(HUB) as PackedScene
	if packed == null:
		_fail("VOLTAR: hub.tscn não carrega")
		return
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	for i in range(6):
		await process_frame
	var fp: Node = inst.get_node_or_null("%FriendsPanel")
	if fp == null:
		_fail("VOLTAR: hub sem %FriendsPanel")
		inst.queue_free()
		await process_frame
		return
	_open_drawer(fp)
	for i in range(4):
		await process_frame
	lan.call("join_room", "K7H4MP")
	if not bool(lan.call("is_guest")):
		_fail("join_room não marcou guest")
		lan.call("close_session")
		inst.queue_free()
		await process_frame
		return
	var voltar: Button = _find_button(fp, "VOLTAR")
	if voltar == null:
		_fail("tela Entrar sem botão VOLTAR")
		lan.call("close_session")
		inst.queue_free()
		await process_frame
		return
	voltar.pressed.emit()
	await process_frame
	if bool(lan.call("is_guest")) or bool(lan.call("in_session")):
		_fail("VOLTAR na tela Entrar não chamou close_session")
		lan.call("close_session")
		inst.queue_free()
		await process_frame
		return
	inst.queue_free()
	await process_frame
	_pass("VOLTAR na tela Entrar chama close_session")


func _test_host_leave_keeps_room(lan: Node) -> void:
	var code: String = str(lan.call("host_room"))
	if code.is_empty() or not RoomCode.is_valid(code):
		_fail("host_leave: host_room code=%s" % code)
		lan.call("close_session")
		return
	lan.set("in_stage", true)
	if not lan.has_method("host_leave_stage_to_map"):
		_fail("LanSession sem host_leave_stage_to_map")
		lan.call("close_session")
		return
	lan.call("host_leave_stage_to_map")
	if bool(lan.get("in_stage")):
		_fail("host_leave_stage_to_map não zerou in_stage")
		lan.call("close_session")
		return
	if not bool(lan.call("is_host")) or not bool(lan.call("in_session")):
		_fail("host_leave_stage_to_map fechou a sala")
		lan.call("close_session")
		return
	lan.call("close_session")
	_pass("host sai ao mapa: in_stage=false e sala permanece")


func _test_guest_clears_packed(lan: Node) -> void:
	lan.call("join_room", "K7H4MP")
	if not bool(lan.call("is_guest")):
		_fail("guest packed: join_room falhou")
		lan.call("close_session")
		return
	lan.call("_rpc_welcome", "HostSmoke", "tanjiro")
	if not bool(lan.call("has_peer")):
		_fail("guest packed: handshake local não marcou peer")
		lan.call("close_session")
		return
	var packed: PackedScene = load("res://scenes/battle/stage_w1_01.tscn") as PackedScene
	if packed == null:
		_fail("guest packed: stage_w1_01.tscn não carrega")
		lan.call("close_session")
		return
	var stage: Node = packed.instantiate()
	root.add_child(stage)
	await process_frame
	if stage.get_node_or_null("Player2") == null:
		_fail("guest packed: coop não spawnou Player2")
		stage.queue_free()
		lan.call("close_session")
		await process_frame
		return
	var live_ai: int = 0
	for n: Node in root.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(n):
			continue
		if n.is_queued_for_deletion():
			continue
		if n.get("net_puppet") == true:
			continue
		live_ai += 1
	stage.queue_free()
	lan.call("close_session")
	await process_frame
	if live_ai > 0:
		_fail("guest _ready deixou %d oni packed com AI" % live_ai)
		return
	_pass("guest _ready limpa group enemy (net_puppet + queue_free)")


func _test_boot_never_conectando() -> void:
	var files: Array[String] = [
		"res://scripts/boot/loading.gd",
		"res://scripts/boot/splash_studio.gd",
		"res://scenes/boot/loading.tscn",
	]
	for path in files:
		if not FileAccess.file_exists(path):
			_fail("boot ausente: %s" % path)
			return
		var txt: String = FileAccess.get_file_as_string(path)
		if txt.contains("Conectando-se"):
			_fail("boot fala Conectando-se… em %s" % path)
			return
	var loading: String = FileAccess.get_file_as_string("res://scripts/boot/loading.gd")
	if not loading.contains("Carregando"):
		_fail("loading.gd sem Carregando…")
		return
	_pass("boot nunca Conectando-se…")


func _test_max_clients(lan: Node) -> void:
	lan.call("close_session")
	if int(lan.get("MAX_CLIENTS")) != 1:
		_fail("MAX_CLIENTS default=%s (deve ser 1)" % lan.get("MAX_CLIENTS"))
		return
	var code: String = str(lan.call("host_room"))
	if code.is_empty():
		_fail("max_clients: host_room falhou")
		return
	if int(lan.get("MAX_CLIENTS")) != 1:
		_fail("2 vs oni MAX_CLIENTS=%s (deve ser 1)" % lan.get("MAX_CLIENTS"))
		lan.call("close_session")
		return
	if not bool(lan.call("set_game_mode", GameMode.Id.VS_ONI_4)):
		_fail("set_game_mode 4 vs oni falhou")
		lan.call("close_session")
		return
	if int(lan.get("MAX_CLIENTS")) != 3:
		_fail("4 vs oni MAX_CLIENTS=%s (deve ser 3)" % lan.get("MAX_CLIENTS"))
		lan.call("close_session")
		return
	if not bool(lan.call("is_four_vs_oni")):
		_fail("is_four_vs_oni falso após modo 4")
		lan.call("close_session")
		return
	lan.call("close_session")
	if int(lan.get("MAX_CLIENTS")) != 1:
		_fail("close_session não voltou MAX_CLIENTS=1")
		return
	_pass("MAX_CLIENTS=1 no 2P e =3 no modo 4")


func _test_game_mode_contract() -> void:
	if GameMode.max_clients_for(GameMode.Id.VS_ONI_2) != 1:
		_fail("GameMode 2 vs oni max_clients != 1")
		return
	if GameMode.max_clients_for(GameMode.Id.VS_ONI_4) != 3:
		_fail("GameMode 4 vs oni max_clients != 3")
		return
	if GameMode.scene_path(GameMode.Id.BRAWL) != "res://scenes/modes/brawl/brawl_arena.tscn":
		_fail("porta Brawl errada")
		return
	if GameMode.scene_path(GameMode.Id.DUEL) != "res://scenes/modes/duel/duel.tscn":
		_fail("porta 1v1 errada")
		return
	if GameMode.label_of(GameMode.Id.VS_ONI_2) != "2 vs oni":
		_fail("label 2 vs oni")
		return
	if GameMode.label_of(GameMode.Id.VS_ONI_4) != "4 vs oni":
		_fail("label 4 vs oni")
		return
	if GameMode.label_of(GameMode.Id.BRAWL) != "Mapa de batalha":
		_fail("label Mapa de batalha")
		return
	if GameMode.label_of(GameMode.Id.DUEL) != "1v1":
		_fail("label 1v1")
		return
	var blob: String = FileAccess.get_file_as_string("res://scripts/net/game_mode.gd")
	blob += FileAccess.get_file_as_string("res://scripts/ui/friends_panel.gd")
	if blob.contains("partida"):
		_fail("texto usa a palavra partida")
		return
	_pass("contrato GameMode (4 opções, MAX_CLIENTS, portas)")


func _test_mode_options() -> void:
	var packed: PackedScene = load(HUB) as PackedScene
	if packed == null:
		_fail("modos: hub.tscn não carrega")
		return
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	for i in range(8):
		await process_frame
	var fp: Node = inst.get_node_or_null("%FriendsPanel")
	if fp == null:
		_fail("modos: hub sem %FriendsPanel")
		inst.queue_free()
		await process_frame
		return
	_open_drawer(fp)
	for i in range(4):
		await process_frame
	var criar: Button = _find_button(fp, "Criar sala")
	if criar == null:
		_fail("modos: sem Criar sala")
		inst.queue_free()
		await process_frame
		return
	criar.pressed.emit()
	for i in range(6):
		await process_frame
	var want: Array[String] = ["2 vs oni", "4 vs oni", "Mapa de batalha", "1v1"]
	for t in want:
		var b: Button = _find_button(fp, t)
		if b == null:
			_fail("sala sem opção %s" % t)
			inst.queue_free()
			await process_frame
			return
		if b.size.y < 44.0:
			_fail("opção %s toque baixo: %.0f" % [t, b.size.y])
			inst.queue_free()
			await process_frame
			return
		if t.contains(" ") and _space_px(b) < 3.0:
			_fail("opção %s: U+0020 advance=%.2f" % [t, _space_px(b)])
			inst.queue_free()
			await process_frame
			return
	var play: Button = inst.get_node_or_null("%PlayButton") as Button
	if play != null and play.text.contains("2 vs oni"):
		_fail("JOGAR ouro virou seletor de modo")
		inst.queue_free()
		await process_frame
		return
	var lan: Node = root.get_node_or_null("LanSession")
	if lan != null:
		lan.call("close_session")
	inst.queue_free()
	await process_frame
	_pass("sala mostra 4 opções legíveis; JOGAR intacto")


func _test_mode_doors(lan: Node) -> void:
	var code: String = str(lan.call("host_room"))
	if code.is_empty():
		_fail("portas: host_room falhou")
		return
	var toasts: Array[String] = []
	var cb := func(t: String) -> void:
		toasts.append(t)
	if not lan.toast_requested.is_connected(cb):
		lan.toast_requested.connect(cb)
	if not bool(lan.call("set_game_mode", GameMode.Id.BRAWL)):
		_fail("set_game_mode Brawl falhou")
		lan.call("close_session")
		return
	if not bool(lan.call("is_host")):
		_fail("Brawl fechou a sala")
		lan.call("close_session")
		return
	var brawl_exists := ResourceLoader.exists(GameMode.scene_path(GameMode.Id.BRAWL))
	var saw_brawl_missing := false
	for t in toasts:
		if t == GameMode.TOAST_BRAWL_MISSING:
			saw_brawl_missing = true
			break
	toasts.clear()
	if not bool(lan.call("set_game_mode", GameMode.Id.DUEL)):
		_fail("set_game_mode 1v1 falhou")
		lan.call("close_session")
		return
	if not bool(lan.call("is_host")):
		_fail("1v1 fechou a sala")
		lan.call("close_session")
		return
	var duel_exists := ResourceLoader.exists(GameMode.scene_path(GameMode.Id.DUEL))
	var saw_duel_missing := false
	for t in toasts:
		if t == GameMode.TOAST_DUEL_MISSING:
			saw_duel_missing = true
			break
	if lan.toast_requested.is_connected(cb):
		lan.toast_requested.disconnect(cb)
	lan.call("close_session")
	if brawl_exists:
		if saw_brawl_missing:
			_fail("Brawl com cena ainda avisou que não chegou")
			return
	elif not saw_brawl_missing:
		_fail("Brawl sem cena não avisou em PT")
		return
	if duel_exists:
		if saw_duel_missing:
			_fail("1v1 com cena ainda avisou que não chegou")
			return
	elif not saw_duel_missing:
		_fail("1v1 sem cena não avisou em PT")
		return
	_pass("portas Brawl/1v1: cena ou toast PT, sala fica")


func _test_four_hunters(lan: Node) -> void:
	lan.call("close_session")
	lan.call("join_room", "K7H4MP")
	if not bool(lan.call("is_guest")):
		_fail("4P: join_room falhou")
		lan.call("close_session")
		return
	lan.call("_rpc_welcome", "HostSmoke", "tanjiro", 1, GameMode.Id.VS_ONI_4)
	var roster: Array = [
		{"slot": 0, "nick": "HostSmoke", "char_id": "tanjiro"},
		{"slot": 1, "nick": "G1", "char_id": "tanjiro"},
		{"slot": 2, "nick": "G2", "char_id": "nezuko"},
		{"slot": 3, "nick": "G3", "char_id": "zenitsu"},
	]
	lan.call("_rpc_roster", GameMode.Id.VS_ONI_4, roster)
	if not bool(lan.call("is_four_vs_oni")):
		_fail("4P: modo não ficou VS_ONI_4")
		lan.call("close_session")
		return
	if int(lan.call("hunter_count")) != 4:
		_fail("4P: hunter_count=%s" % lan.call("hunter_count"))
		lan.call("close_session")
		return
	var packed: PackedScene = load("res://scenes/battle/stage_w1_01.tscn") as PackedScene
	if packed == null:
		_fail("4P: stage_w1_01.tscn não carrega")
		lan.call("close_session")
		return
	var stage: Node = packed.instantiate()
	root.add_child(stage)
	await process_frame
	var missing: Array[String] = []
	for name in ["Player2", "Player3", "Player4"]:
		if stage.get_node_or_null(name) == null:
			missing.append(name)
	var cam: Node = stage.get_node_or_null("CoopCamera")
	var ntargets: int = 0
	if cam != null:
		var tg: Variant = cam.get("_targets")
		if tg is Array:
			ntargets = (tg as Array).size()
	stage.queue_free()
	lan.call("close_session")
	await process_frame
	if not missing.is_empty():
		_fail("4P não spawnou %s" % str(missing))
		return
	if ntargets < 4:
		_fail("câmera 4P targets=%d (precisa 4)" % ntargets)
		return
	_pass("4P: 4 caçadores + câmera nos vivos")


func _test_meio_self_test() -> void:
	var script: String = ProjectSettings.globalize_path("res://tools/sala_meio.py")
	if not FileAccess.file_exists("res://tools/sala_meio.py"):
		_fail("tools/sala_meio.py ausente (self-test)")
		return
	var output: Array = []
	var code: int = OS.execute("python", PackedStringArray([script, "--self-test"]), output, true)
	if code != 0:
		output.clear()
		code = OS.execute("py", PackedStringArray(["-3", script, "--self-test"]), output, true)
	var txt := ""
	for line in output:
		txt += str(line) + "\n"
	if code != 0 or not txt.contains("sala_meio self-test PASS"):
		_fail("sala_meio --self-test falhou (exit=%d txt=%s)" % [code, txt.strip_edges()])
		return
	_pass("sala_meio --self-test (proto lixo / relay 1:1 / poll sem code)")


func _test_meio_parse() -> void:
	if not SalaMeioClient.parse_endpoint("").is_empty():
		_fail("parse vazio deveria falhar")
		return
	var a: Dictionary = SalaMeioClient.parse_endpoint("127.0.0.1")
	if str(a.get("host", "")) != "127.0.0.1" or int(a.get("port", 0)) != 17779:
		_fail("parse 127.0.0.1 = %s" % a)
		return
	var b: Dictionary = SalaMeioClient.parse_endpoint("pc-sala:18779")
	if str(b.get("host", "")) != "pc-sala" or int(b.get("port", 0)) != 18779:
		_fail("parse hostname:porta = %s" % b)
		return
	if not SalaMeioClient.parse_endpoint("nope:99999").is_empty():
		_fail("aceitou porta inválida")
		return
	_pass("SalaMeioClient.parse_endpoint")


func _test_meio_pc_off(lan: Node) -> void:
	var toasts: Array[String] = []
	var cb := func(t: String) -> void:
		toasts.append(t)
	if not lan.toast_requested.is_connected(cb):
		lan.toast_requested.connect(cb)
	lan.call("set_sala_meio", "127.0.0.1:1")
	if not bool(lan.call("has_sala_meio")):
		_fail("set_sala_meio 127.0.0.1:1 falhou")
		lan.call("set_sala_meio", "")
		lan.call("close_session")
		return
	var code: String = str(lan.call("host_room"))
	if code.is_empty() or not RoomCode.is_valid(code):
		_fail("PC off: host_room falhou code=%s" % code)
		lan.call("set_sala_meio", "")
		lan.call("close_session")
		return
	if not bool(lan.call("is_host")):
		_fail("PC off: sala LAN não abriu")
		lan.call("set_sala_meio", "")
		lan.call("close_session")
		return
	var saw_off := false
	for t in toasts:
		if t.contains("desligado"):
			saw_off = true
			break
	lan.call("close_session")
	lan.call("set_sala_meio", "")
	if lan.toast_requested.is_connected(cb):
		lan.toast_requested.disconnect(cb)
	if not saw_off:
		_fail("PC off: sem aviso PT (toasts=%s)" % str(toasts))
		return
	_pass("PC desligado: sala LAN abre e avisa em PT")


func _test_meio_not_in_friends_save(lan: Node) -> void:
	lan.call("set_sala_meio", "10.0.0.8:17779")
	_game.call("add_friend", "MeioSave")
	_game.call("save_game")
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEMP_SAVE))
	lan.call("set_sala_meio", "")
	if typeof(payload) != TYPE_DICTIONARY:
		_fail("save JSON inválido após meio")
		return
	var txt: String = JSON.stringify(payload)
	if txt.contains("10.0.0.8") or txt.contains("17779"):
		_fail("save gravou IP do computador da sala")
		return
	_pass("computador da sala não entra no save friends")


func _test_hub_computador_field() -> void:
	var packed: PackedScene = load(HUB) as PackedScene
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	for i in range(6):
		await process_frame
	var fp: Node = inst.get_node_or_null("%FriendsPanel")
	if fp == null:
		_fail("campo: hub sem FriendsPanel")
		inst.queue_free()
		await process_frame
		return
	_open_drawer(fp)
	for i in range(4):
		await process_frame
	var edit: LineEdit = _find_line_placeholder(fp, "só o Wi-Fi")
	if edit == null:
		_fail("campo Computador da sala sem LineEdit")
		inst.queue_free()
		await process_frame
		return
	edit.text = "127.0.0.1:17779"
	edit.text_changed.emit(edit.text)
	var lan: Node = root.get_node_or_null("LanSession")
	if lan == null or str(lan.call("get_sala_meio")) != "127.0.0.1:17779":
		_fail("campo não foi para LanSession")
		if lan != null:
			lan.call("set_sala_meio", "")
		inst.queue_free()
		await process_frame
		return
	lan.call("set_sala_meio", "")
	inst.queue_free()
	await process_frame
	_pass("campo Computador da sala grava no autoload, não no save")


func _test_call_name_not_x() -> void:
	_game.set("friends", [])
	_game.call("add_friend", "SobrinhoQA")
	var packed: PackedScene = load(HUB) as PackedScene
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	for i in range(8):
		await process_frame
	var fp: Node = inst.get_node_or_null("%FriendsPanel")
	if fp == null:
		_fail("chamar: hub sem FriendsPanel")
		inst.queue_free()
		await process_frame
		return
	_open_drawer(fp)
	for i in range(6):
		await process_frame
	var xbtn: Button = _find_friend_remove_btn(fp, "SobrinhoQA")
	if xbtn == null:
		_fail("chamar: sem botão x do SobrinhoQA")
		inst.queue_free()
		await process_frame
		return
	var lan: Node = root.get_node_or_null("LanSession")
	var toasts: Array[String] = []
	var cb := func(t: String) -> void:
		toasts.append(t)
	if lan != null and not lan.toast_requested.is_connected(cb):
		lan.toast_requested.connect(cb)
	if lan != null:
		lan.call("set_sala_meio", "")
		lan.call("call_friend", "SobrinhoQA")
	var need_pc := false
	for t in toasts:
		if t.contains("código") or t.contains("computador da sala"):
			need_pc = true
			break
	if lan != null and lan.toast_requested.is_connected(cb):
		lan.toast_requested.disconnect(cb)
	var before: int = 0
	for d in _game.get("friends"):
		if str(d.get("name", "")) == "SobrinhoQA":
			before += 1
	xbtn.emit_signal("pressed")
	await process_frame
	var after: int = 0
	for d in _game.get("friends"):
		if str(d.get("name", "")) == "SobrinhoQA":
			after += 1
	if after != 0:
		for conn in xbtn.get_signal_connection_list("pressed"):
			var cb_rm: Variant = conn.get("callable", Callable())
			if cb_rm is Callable and (cb_rm as Callable).is_valid():
				(cb_rm as Callable).call()
		await process_frame
		after = 0
		for d in _game.get("friends"):
			if str(d.get("name", "")) == "SobrinhoQA":
				after += 1
	inst.queue_free()
	await process_frame
	if not need_pc:
		_fail("toque no nome sem PC não avisou (toasts=%s)" % str(toasts))
		return
	if before < 1 or after != 0:
		_fail("x não apagou o amigo (antes=%d depois=%d)" % [before, after])
		return
	_pass("toque no nome chama; x apaga")


func _test_meio_two_process(lan: Node) -> void:
	var script: String = ProjectSettings.globalize_path("res://tools/sala_meio.py")
	if not FileAccess.file_exists("res://tools/sala_meio.py"):
		_fail("tools/sala_meio.py ausente")
		return
	var port: int = 18779
	var extra := PackedStringArray([script, "--bind", "127.0.0.1", "--port", str(port)])
	var pid: int = OS.create_process("python", extra)
	if pid <= 0:
		var py_args := PackedStringArray(["-3"])
		py_args.append_array(extra)
		pid = OS.create_process("py", py_args)
	if pid <= 0:
		_fail("não subiu sala_meio.py (pid=%d)" % pid)
		return
	OS.delay_msec(400)
	lan.call("close_session")
	lan.call("set_sala_meio", "127.0.0.1:%d" % port)
	var client := SalaMeioClient.new()
	client.set_endpoint("127.0.0.1:%d" % port)
	if not client.ping():
		OS.kill(pid)
		lan.call("set_sala_meio", "")
		_fail("ping 127.0.0.1:%d falhou (PC no meio)" % port)
		return
	var junk := PacketPeerUDP.new()
	if junk.bind(0, "127.0.0.1") == OK:
		junk.set_dest_address("127.0.0.1", port)
		junk.put_packet('{"magic":"HASHIRA_MEIO","proto":["x"],"op":"ping"}'.to_utf8_buffer())
		OS.delay_msec(80)
		junk.close()
	if not client.ping():
		OS.kill(pid)
		lan.call("set_sala_meio", "")
		_fail("proto lixo derrubou sala_meio.py")
		return
	var announced: Dictionary = client.announce("K7H4MP", 17777, "HostSmoke", 1)
	if str(announced.get("op", "")) != "announced":
		OS.kill(pid)
		lan.call("set_sala_meio", "")
		_fail("announce = %s" % announced)
		return
	var found: Dictionary = client.lookup("K7H4MP")
	if str(found.get("op", "")) != "found":
		OS.kill(pid)
		lan.call("set_sala_meio", "")
		_fail("lookup = %s" % found)
		return
	if str(found.get("ip", "")) != "127.0.0.1":
		OS.kill(pid)
		lan.call("set_sala_meio", "")
		_fail("lookup ip=%s" % found.get("ip", ""))
		return
	client.presence("SobrinhoQA", "")
	var called: Dictionary = client.call_nick("HostSmoke", "SobrinhoQA")
	if str(called.get("op", "")) != "called":
		OS.kill(pid)
		lan.call("set_sala_meio", "")
		_fail("call online = %s" % called)
		return
	var ghost: Dictionary = client.call_nick("HostSmoke", "Ninguem")
	if str(ghost.get("op", "")) != "offline":
		OS.kill(pid)
		lan.call("set_sala_meio", "")
		_fail("call offline = %s" % ghost)
		return
	var inbox: Dictionary = client.poll_calls("SobrinhoQA")
	if str(inbox.get("op", "")) != "inbox":
		OS.kill(pid)
		lan.call("set_sala_meio", "")
		_fail("poll inbox = %s" % inbox)
		return
	var leaked := false
	var calls: Variant = inbox.get("calls", [])
	if calls is Array:
		for item in calls:
			if typeof(item) == TYPE_DICTIONARY and (item as Dictionary).has("code"):
				leaked = true
				break
	if leaked:
		OS.kill(pid)
		lan.call("set_sala_meio", "")
		_fail("poll devolveu code da sala: %s" % inbox)
		return
	lan.call("join_room", "K7H4MP")
	if not bool(lan.call("is_guest")):
		OS.kill(pid)
		lan.call("close_session")
		lan.call("set_sala_meio", "")
		_fail("join_room guest falhou com PC no meio")
		return
	if bool(lan.get("_meio_lookup_tried")):
		OS.kill(pid)
		lan.call("close_session")
		lan.call("set_sala_meio", "")
		_fail("beacon ainda não esgotou e já perguntou ao PC")
		return
	lan.call("close_session")
	lan.call("set_sala_meio", "")
	OS.kill(pid)
	_pass("PC no meio localhost (2 processos): ping/announce/lookup/chamar; beacon primeiro")


func _finish() -> void:
	var lan: Node = root.get_node_or_null("LanSession")
	if lan != null and lan.has_method("close_session"):
		lan.call("close_session")
	_restore()
	print("=== smoke_lan_friends ===")
	for m in _messages:
		print("  - ", m)
	if _ok:
		print("LAN_FRIENDS PASS")
		quit(0)
	else:
		print("LAN_FRIENDS FAIL")
		quit(1)
