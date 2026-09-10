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
	inst.queue_free()
	await process_frame
	_pass("hub tem %FriendsPanel")


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
