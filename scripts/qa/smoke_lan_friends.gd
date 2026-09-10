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
	_test_meio_parse()
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
	for i in range(6):
		await process_frame
	var fp: Node = inst.get_node_or_null("%FriendsPanel")
	if fp == null:
		_fail("hub sem %FriendsPanel")
		inst.queue_free()
		await process_frame
		return
	if not fp.visible:
		_fail("FriendsPanel invisível")
		inst.queue_free()
		await process_frame
		return
	if _find_label(fp, "Computador da sala") == null:
		_fail("FriendsPanel sem campo Computador da sala")
		inst.queue_free()
		await process_frame
		return
	inst.queue_free()
	await process_frame
	_pass("hub tem %FriendsPanel + Computador da sala")


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
	if int(lan.get("MAX_CLIENTS")) != 1:
		_fail("MAX_CLIENTS=%s (deve ser 1)" % lan.get("MAX_CLIENTS"))
		return
	_pass("max_clients=1")


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
