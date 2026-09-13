extends Node
## Sessão LAN 2P/4P. Autoload fino: peer, beacon, handshake, RPCs de sessão.
## Combate, moeda e loja não moram aqui. Modo: `GameMode` (scripts/net/game_mode.gd).

const ENET_PORT := 17777
const PROTO := 1
const BEACON_HZ := 2.0
const INPUT_HZ := 20.0
const ONI_SYNC_HZ := 10.0
const BEACON_WAIT_MS := 2500
const LEASH_X := 720.0
const MEIO_ANNOUNCE_HZ := 0.4
const MEIO_CALL_HZ := 1.0
const MEIO_LOOKUP_RETRY_MS := 1000
const MEIO_LOOKUP_GIVE_UP_MS := 20000
const MSG_PC_OFF := "A sala da estrela está desligada"
const MSG_FRIEND_OFF := "O amigo não está aí agora"
const MSG_CALL_NEED_PC := "Mande o código da sala"
const MSG_SALA_MISSING := "Sala não achada na sala da estrela"
const MSG_CREATE_ROOM_FIRST := "Cria a sala primeiro"
const MSG_NEED_FRIEND_NAME := "Adiciona ele na lista primeiro"

signal peer_joined(nick: String)
signal peer_left
signal room_ready(code: String)
signal join_failed(reason_pt: String)
signal handshake_rejected(reason_pt: String)
signal stage_load(path: String)
signal toast_requested(text: String)
signal session_closed
signal stage_cleared_event(stage_id: String, coins: int)
signal stage_wipe
signal waves_unlocked
signal mode_changed(mode_id: int)
signal room_invite_received(from_nick: String, code: String)
signal roster_changed
signal rematch_changed

enum Role { NONE, HOST, GUEST }

## Teto ENet da sala (sempre 3 depois de Criar). Cap do modo = GameMode.max_clients_for.
var MAX_CLIENTS: int = 1
var game_mode: int = GameMode.Id.VS_ONI_2
## Guest: slot que este celular controla (host = 0).
var local_coop_slot: int = 0

var role: int = Role.NONE
var room_code: String = ""
var remote_nick: String = ""
var remote_character_id: String = "tanjiro"
var guest_peer_id: int = 0
var in_stage: bool = false
## peer_id -> {slot, nick, char_id}
var _guests: Dictionary = {}
var _roster: Array = []

var _beacon: LanBeacon = LanBeacon.new()
var _beacon_t: float = 0.0
var _listen_since_ms: int = 0
var _listening_for_code: String = ""
var _input_t: float = 0.0
var _pending_just: int = 0
var _oni_t: float = 0.0
var _next_oni_id: int = 1
var _guest_onis: Dictionary = {} # net_id -> Node
var _handshake_ok: bool = false
var _connect_signals_hooked: bool = false
var _meio: SalaMeioClient = SalaMeioClient.new()
var _relay_bridge: EnetRelayBridge = EnetRelayBridge.new()
var _meio_announce_t: float = 0.0
var _meio_call_t: float = 0.0
var _meio_lookup_tried: bool = false
var _meio_next_lookup_ms: int = 0
var _meio_pc_off_told: bool = false
## slot -> quer revanche
var _rematch_votes: Dictionary = {}


func _ready() -> void:
	_apply_baked_sala()
	var win := get_window()
	if win != null and not win.close_requested.is_connected(_on_window_close):
		win.close_requested.connect(_on_window_close)


func _apply_baked_sala() -> void:
	if _meio.is_configured():
		return
	_meio.apply_baked()


func _on_window_close() -> void:
	close_session()


func is_host() -> bool:
	return role == Role.HOST


func is_guest() -> bool:
	return role == Role.GUEST


func has_peer() -> bool:
	return _handshake_ok


func in_session() -> bool:
	return role != Role.NONE


func in_stage_session() -> bool:
	return in_session() and in_stage and _handshake_ok


func hunter_count() -> int:
	return get_roster().size() if has_peer() else 1


func is_four_vs_oni() -> bool:
	return game_mode == GameMode.Id.VS_ONI_4


func get_roster() -> Array:
	if is_guest() and not _roster.is_empty():
		return _roster.duplicate()
	var out: Array = []
	var host_char: String = str(Game.current_character_id)
	var host_nick: String = _nick()
	if is_guest():
		host_char = remote_character_id if not remote_character_id.is_empty() else "tanjiro"
		host_nick = remote_nick if not remote_nick.is_empty() else "Anfitrião"
	out.append({"slot": 0, "nick": host_nick, "char_id": host_char})
	if is_guest():
		var gs: int = local_coop_slot if local_coop_slot > 0 else 1
		out.append({"slot": gs, "nick": _nick(), "char_id": str(Game.current_character_id)})
		return out
	for g in _guests.values():
		if typeof(g) == TYPE_DICTIONARY:
			out.append(g)
	return out


func set_game_mode(mode_id: int) -> bool:
	if not is_host():
		return false
	if not GameMode.is_vs_oni(mode_id):
		var path := GameMode.scene_path(mode_id)
		if path.is_empty() or not ResourceLoader.exists(path):
			toast_requested.emit(GameMode.missing_toast(mode_id))
			return true
	var cap: int = GameMode.max_clients_for(mode_id)
	if _guests.size() > cap:
		toast_requested.emit(GameMode.TOAST_MODE_TOO_FULL)
		return false
	game_mode = mode_id
	mode_changed.emit(mode_id)
	_broadcast_roster()
	return true


func start_selected_mode() -> bool:
	if not is_host():
		return false
	if GameMode.is_vs_oni(game_mode):
		if _handshake_ok:
			toast_requested.emit("Escolhe a fase no mapa")
		return SceneRouter.to_world_map()
	var path := GameMode.scene_path(game_mode)
	if path.is_empty() or not ResourceLoader.exists(path):
		toast_requested.emit(GameMode.missing_toast(game_mode))
		return false
	if _handshake_ok:
		announce_stage(path)
	SceneRouter.go_to(path)
	return true


func _resize_server(want: int) -> bool:
	if want == MAX_CLIENTS:
		return true
	if not is_host() or room_code.is_empty():
		return false
	if _handshake_ok or not _guests.is_empty():
		toast_requested.emit("Fecha a sala para mudar o número de caçadores")
		return false
	var code := room_code
	_beacon.stop()
	_unhook_peer_signals()
	if multiplayer.multiplayer_peer != null:
		var old: MultiplayerPeer = multiplayer.multiplayer_peer
		multiplayer.multiplayer_peer = null
		if old is ENetMultiplayerPeer:
			(old as ENetMultiplayerPeer).close()
	MAX_CLIENTS = want
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(ENET_PORT, MAX_CLIENTS)
	if err != OK:
		join_failed.emit("Não deu para abrir a sala")
		MAX_CLIENTS = 1
		return false
	multiplayer.multiplayer_peer = peer
	_hook_peer_signals()
	room_code = code
	var nick := _nick()
	if not _beacon.start_broadcast(room_code, ENET_PORT, nick, _version_code()):
		toast_requested.emit("Beacon da sala falhou. O código ainda vale.")
	_beacon_t = 0.0
	return true


func set_sala_meio(raw: String) -> bool:
	_meio_pc_off_told = false
	return _meio.set_endpoint(raw)


func get_sala_meio() -> String:
	return _meio.endpoint_text()


func has_sala_meio() -> bool:
	return _meio.is_configured()


func _friend_id() -> String:
	if is_instance_valid(Game) and Game.has_method("ensure_friend_code"):
		return str(Game.ensure_friend_code())
	return ""


func call_friend(raw_nick: String) -> void:
	invite_friend_to_room(raw_nick)


func send_friend_invite(raw_name: String) -> void:
	if _in_boot():
		return
	var dest_name := Game.sanitize_player_name(raw_name)
	if dest_name.is_empty():
		toast_requested.emit("Escreve o nome dele")
		return
	if dest_name == _nick():
		toast_requested.emit("Esse nome é o seu")
		return
	if is_instance_valid(Game) and Game.has_method("has_friend_named") and bool(Game.has_friend_named(dest_name)):
		toast_requested.emit("Já é amigo")
		return
	if not has_sala_meio():
		toast_requested.emit(MSG_CALL_NEED_PC)
		return
	if not _meio.ping():
		toast_requested.emit(MSG_PC_OFF)
		return
	_meio.presence(_nick(), room_code if is_host() else "", _friend_id())
	var reply: Dictionary = _meio.friend_invite(_friend_id(), _nick(), "", dest_name)
	var op := str(reply.get("op", ""))
	var dest_id := str(reply.get("to", ""))
	if op == "offline":
		toast_requested.emit(MSG_FRIEND_OFF)
		return
	if op == "already":
		if is_instance_valid(Game):
			Game.add_friend(dest_name, dest_id)
		toast_requested.emit("Já é amigo")
		return
	if op != "invited":
		toast_requested.emit("Não deu para mandar o convite")
		return
	if is_instance_valid(Game):
		Game.remember_outgoing_invite(dest_id, dest_name)
	toast_requested.emit("Convite enviado")


func accept_friend_invite(raw_id: String) -> void:
	if _in_boot():
		return
	var dest := FriendCode.normalize(raw_id)
	if not FriendCode.is_valid(dest):
		return
	var incoming_name := "Amigo"
	if is_instance_valid(Game):
		for d in Game.pending_in:
			if str(d.get("friend_id", "")) == dest:
				incoming_name = str(d.get("name", incoming_name))
				break
	if not has_sala_meio():
		toast_requested.emit(MSG_CALL_NEED_PC)
		return
	if not _meio.ping():
		toast_requested.emit(MSG_PC_OFF)
		return
	var reply: Dictionary = _meio.friend_accept(_friend_id(), _nick(), dest)
	if str(reply.get("op", "")) != "accepted":
		toast_requested.emit("Convite não está mais aí")
		if is_instance_valid(Game):
			Game.remove_incoming_invite(dest)
		return
	if is_instance_valid(Game):
		Game.add_friend(incoming_name, dest)
	toast_requested.emit("Amigo adicionado")


func decline_friend_invite(raw_id: String) -> void:
	var dest := FriendCode.normalize(raw_id)
	if not FriendCode.is_valid(dest):
		return
	if has_sala_meio() and _meio.ping():
		_meio.friend_decline(_friend_id(), dest)
	if is_instance_valid(Game):
		Game.remove_incoming_invite(dest)
	toast_requested.emit("Convite recusado")


func invite_friend_to_room(raw_nick: String) -> void:
	if _in_boot():
		return
	var dest_name := Game.sanitize_player_name(raw_nick)
	if dest_name.is_empty():
		return
	if not is_host() or room_code.is_empty():
		toast_requested.emit(MSG_CREATE_ROOM_FIRST)
		return
	var dest_id := ""
	if is_instance_valid(Game):
		dest_id = Game.friend_id_of(dest_name)
	if dest_id.is_empty() and dest_name.is_empty():
		toast_requested.emit(MSG_NEED_FRIEND_NAME)
		return
	if not has_sala_meio():
		toast_requested.emit(MSG_CALL_NEED_PC)
		return
	if not _meio.ping():
		toast_requested.emit(MSG_PC_OFF)
		return
	_meio.presence(_nick(), room_code, _friend_id())
	var reply: Dictionary = _meio.room_invite(_friend_id(), _nick(), dest_id, room_code, dest_name)
	if str(reply.get("op", "")) != "invited":
		toast_requested.emit(MSG_FRIEND_OFF)
		return
	toast_requested.emit("Convite da sala enviado")


func _version_code() -> int:
	if is_instance_valid(AutoUpdater) and AutoUpdater.has_method("get_local_version_code"):
		return int(AutoUpdater.get_local_version_code())
	return 0


func _nick() -> String:
	var n := Game.sanitize_player_name(Game.player_name)
	if n.is_empty():
		n = "Caçador"
	return n


func host_room() -> String:
	close_session()
	game_mode = GameMode.Id.VS_ONI_2
	MAX_CLIENTS = GameMode.ENET_CEILING
	local_coop_slot = 0
	room_code = RoomCode.generate()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(ENET_PORT, MAX_CLIENTS)
	if err != OK:
		join_failed.emit("Não deu para abrir a sala")
		room_code = ""
		return ""
	multiplayer.multiplayer_peer = peer
	role = Role.HOST
	_handshake_ok = false
	guest_peer_id = 0
	_hook_peer_signals()
	var nick := _nick()
	if not _beacon.start_broadcast(room_code, ENET_PORT, nick, _version_code()):
		toast_requested.emit("Beacon da sala falhou. O código ainda vale.")
	_beacon_t = 0.0
	_meio_announce_t = 0.0
	_meio_pc_off_told = false
	_try_meio_announce(true)
	_start_host_relay_bridge()
	room_ready.emit(room_code)
	return room_code


func join_room(code: String) -> void:
	var n := RoomCode.normalize(code)
	if not RoomCode.is_valid(n):
		join_failed.emit("Código inválido")
		return
	close_session()
	role = Role.GUEST
	room_code = n
	_listening_for_code = n
	_listen_since_ms = Time.get_ticks_msec()
	_meio_lookup_tried = false
	_meio_next_lookup_ms = 0
	_meio_pc_off_told = false
	if not _beacon.start_listen():
		toast_requested.emit("Não achou na rede. Mesmo Wi-Fi, sem convidado isolado.")
	if has_sala_meio():
		toast_requested.emit("Procurando o amigo…")
	else:
		toast_requested.emit("Procurando na rede…")


func join_wait_elapsed_ms() -> int:
	if _listening_for_code.is_empty():
		return 0
	return Time.get_ticks_msec() - _listen_since_ms


func join_by_ip(ip: String, code: String = "") -> void:
	var clean := ip.strip_edges()
	if clean.is_empty():
		clean = "127.0.0.1"
	if not _is_ipv4(clean):
		join_failed.emit("IP inválido")
		return
	if not code.is_empty():
		var n := RoomCode.normalize(code)
		if not RoomCode.is_valid(n):
			join_failed.emit("Código inválido")
			return
		if role != Role.GUEST:
			close_session()
			role = Role.GUEST
			room_code = n
	elif role != Role.GUEST:
		if room_code.is_empty() or not RoomCode.is_valid(room_code):
			join_failed.emit("Código inválido")
			return
		role = Role.GUEST
	_listening_for_code = ""
	_beacon.stop_listen()
	_connect_enet(clean)


func announce_stage(path: String) -> void:
	if not is_host() or not _handshake_ok:
		return
	_rpc_load_stage.rpc(path)


func notify_guest_host_picks() -> void:
	if is_guest() and _handshake_ok and not in_stage:
		toast_requested.emit("O anfitrião escolhe a fase")


func host_leave_stage_to_map() -> void:
	## Pause host "Sair para o mapa": sala permanece, guest volta ao hub.
	if not is_host():
		return
	in_stage = false
	_oni_t = 0.0
	_next_oni_id = 1
	_clear_rematch_votes()
	if _handshake_ok:
		_rpc_host_picking_stage.rpc()


func nick_for_slot(slot: int) -> String:
	for item: Variant in get_roster():
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec := item as Dictionary
		if int(rec.get("slot", -1)) != slot:
			continue
		var n := Game.sanitize_player_name(str(rec.get("nick", "")))
		if not n.is_empty():
			return n
	if slot == 0:
		return _nick()
	return "Amigo"


func keep_room_after_stage() -> void:
	in_stage = false
	_pending_just = 0
	_input_t = 0.0
	_oni_t = 0.0
	_clear_rematch_votes()
	if is_host() and _handshake_ok:
		_rpc_host_picking_stage.rpc()


func return_to_room_lobby() -> void:
	if is_guest() and _handshake_ok:
		_rpc_submit_rematch.rpc_id(1, false)
		return
	keep_room_after_stage()
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	Engine.time_scale = 1.0
	if is_inside_tree():
		call_deferred("_go_hub_keep_room")


func vote_rematch(want: bool) -> void:
	if not in_session():
		return
	var slot: int = 0 if is_host() else (local_coop_slot if local_coop_slot > 0 else 1)
	if is_host():
		_set_rematch_vote(slot, want)
		return
	_rematch_votes[slot] = want
	rematch_changed.emit()
	if _handshake_ok:
		_rpc_submit_rematch.rpc_id(1, want)


func rematch_wait_text() -> String:
	var slot: int = 0 if is_host() else (local_coop_slot if local_coop_slot > 0 else 1)
	if not _rematch_votes.has(slot):
		return ""
	if bool(_rematch_votes[slot]):
		return "Esperando o amigo…"
	return "Voltando pra sala…"


func _go_hub_keep_room() -> void:
	if not is_inside_tree():
		return
	SceneRouter.to_hub()


func _clear_rematch_votes() -> void:
	_rematch_votes.clear()


func _set_rematch_vote(slot: int, want: bool) -> void:
	_rematch_votes[slot] = want
	rematch_changed.emit()
	if _handshake_ok:
		_rpc_rematch_state.rpc(_rematch_votes_payload())
	_try_resolve_rematch()


func _rematch_votes_payload() -> Array:
	var out: Array = []
	for k: Variant in _rematch_votes.keys():
		out.append({"slot": int(k), "want": bool(_rematch_votes[k])})
	return out


func _try_resolve_rematch() -> void:
	if not is_host() or _rematch_votes.is_empty():
		return
	for v: Variant in _rematch_votes.values():
		if not bool(v):
			keep_room_after_stage()
			var tree := get_tree()
			if tree != null:
				tree.paused = false
			Engine.time_scale = 1.0
			if is_inside_tree():
				call_deferred("_go_hub_keep_room")
			return
	if not _handshake_ok:
		return
	if _rematch_votes.size() < maxi(hunter_count(), 2):
		return
	_clear_rematch_votes()
	start_selected_mode()


@rpc("any_peer", "reliable")
func _rpc_submit_rematch(want: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	_set_rematch_vote(_slot_of_peer(sender), want)


@rpc("authority", "reliable")
func _rpc_rematch_state(votes: Array) -> void:
	if role != Role.GUEST:
		return
	_rematch_votes.clear()
	for item: Variant in votes:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var rec := item as Dictionary
		_rematch_votes[int(rec.get("slot", -1))] = bool(rec.get("want", false))
	rematch_changed.emit()


func close_session() -> void:
	var had: bool = role != Role.NONE
	_beacon.stop()
	_listening_for_code = ""
	_listen_since_ms = 0
	_meio_lookup_tried = false
	_meio_next_lookup_ms = 0
	_relay_bridge.stop()
	_pending_just = 0
	_input_t = 0.0
	_oni_t = 0.0
	_next_oni_id = 1
	_guest_onis.clear()
	_guests.clear()
	_roster.clear()
	in_stage = false
	_clear_rematch_votes()
	remote_nick = ""
	remote_character_id = "tanjiro"
	guest_peer_id = 0
	local_coop_slot = 0
	game_mode = GameMode.Id.VS_ONI_2
	MAX_CLIENTS = 1
	_handshake_ok = false
	_unhook_peer_signals()
	if multiplayer.multiplayer_peer != null:
		var p: MultiplayerPeer = multiplayer.multiplayer_peer
		multiplayer.multiplayer_peer = null
		if p is ENetMultiplayerPeer:
			(p as ENetMultiplayerPeer).close()
	role = Role.NONE
	room_code = ""
	if had:
		session_closed.emit()


func _process(delta: float) -> void:
	if _relay_bridge.active:
		_relay_bridge.pump(delta)
	if role == Role.HOST and not room_code.is_empty():
		_beacon_t += delta
		if _beacon_t >= 1.0 / BEACON_HZ:
			_beacon_t = 0.0
			_beacon.pulse()
	if role == Role.HOST and not room_code.is_empty() and not _in_boot():
		_meio_announce_t += delta
		if _meio_announce_t >= 1.0 / MEIO_ANNOUNCE_HZ:
			_meio_announce_t = 0.0
			_try_meio_announce(false)
	if not _in_boot() and has_sala_meio():
		_meio_call_t += delta
		if _meio_call_t >= 1.0 / MEIO_CALL_HZ:
			_meio_call_t = 0.0
			_poll_meio_calls()
	if role == Role.GUEST and not _listening_for_code.is_empty():
		var hits: Array[Dictionary] = _beacon.poll_matches(_listening_for_code)
		if not hits.is_empty():
			var hit: Dictionary = hits[0]
			var ip := str(hit.get("ip", ""))
			_listening_for_code = ""
			_beacon.stop_listen()
			_relay_bridge.stop()
			_connect_enet(ip)
		elif join_wait_elapsed_ms() >= BEACON_WAIT_MS:
			var now_ms: int = Time.get_ticks_msec()
			if now_ms >= _meio_next_lookup_ms and join_wait_elapsed_ms() <= MEIO_LOOKUP_GIVE_UP_MS + BEACON_WAIT_MS:
				_meio_lookup_tried = true
				_meio_next_lookup_ms = now_ms + MEIO_LOOKUP_RETRY_MS
				call_deferred("_try_meio_lookup")
			elif join_wait_elapsed_ms() > MEIO_LOOKUP_GIVE_UP_MS + BEACON_WAIT_MS and not _meio_pc_off_told:
				_meio_pc_off_told = true
				toast_requested.emit(MSG_SALA_MISSING)
	if role == Role.GUEST and in_stage and _handshake_ok:
		_pending_just |= InputFrame.just_mask_now()
		_input_t += delta
		if _input_t >= 1.0 / INPUT_HZ:
			_input_t = 0.0
			var packed: PackedByteArray = InputFrame.pack_from_local(_pending_just)
			_pending_just = 0
			_rpc_input.rpc_id(1, packed)
	if role == Role.HOST and in_stage and _handshake_ok:
		_oni_t += delta
		if _oni_t >= 1.0 / ONI_SYNC_HZ:
			_oni_t = 0.0
			_broadcast_oni_snaps()


func _physics_process(_delta: float) -> void:
	if role != Role.HOST or not in_stage or not _handshake_ok:
		return
	_broadcast_player_snaps()
	_apply_leash()


func _hook_peer_signals() -> void:
	if _connect_signals_hooked:
		return
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_connect_signals_hooked = true


func _unhook_peer_signals() -> void:
	if not _connect_signals_hooked:
		return
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	_connect_signals_hooked = false


func _drop_peer(id: int) -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)


func _connect_enet(ip: String, port: int = ENET_PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	var use_port: int = port if port > 0 else ENET_PORT
	var err := peer.create_client(ip, use_port)
	if err != OK:
		join_failed.emit("Não conectou. Usem o Wi-Fi da casa.")
		close_session()
		return
	multiplayer.multiplayer_peer = peer
	_hook_peer_signals()


func _on_peer_connected(id: int) -> void:
	if role == Role.HOST:
		guest_peer_id = id
		return
	if role == Role.GUEST:
		_rpc_hello.rpc_id(1, PROTO, _version_code(), _nick(), str(Game.current_character_id))


func _on_peer_disconnected(id: int) -> void:
	if role == Role.HOST:
		var rec: Variant = _guests.get(id, {})
		var slot: int = 1
		if typeof(rec) == TYPE_DICTIONARY:
			slot = int((rec as Dictionary).get("slot", 1))
		_guests.erase(id)
		if guest_peer_id == id:
			guest_peer_id = 0
			if not _guests.is_empty():
				guest_peer_id = int(_guests.keys()[0])
		if _guests.is_empty():
			_handshake_ok = false
			peer_left.emit()
			if in_stage:
				_drop_pawn_slot(slot)
				toast_requested.emit("Amigo saiu — segue solo")
			else:
				toast_requested.emit("Amigo saiu")
			return
		peer_left.emit()
		if in_stage:
			_drop_pawn_slot(slot)
		toast_requested.emit("Amigo saiu")
		_broadcast_roster()
		return
	if role == Role.GUEST:
		toast_requested.emit("Anfitrião saiu")
		close_session()
		SceneRouter.to_hub()


func _drop_guest_pawn() -> void:
	_drop_pawn_slot(1)


func _drop_pawn_slot(slot: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n: Node in tree.get_nodes_in_group("player"):
		if int(n.get("coop_slot")) == slot:
			n.remove_from_group("player")
			n.queue_free()


func _next_free_slot() -> int:
	var used: Dictionary = {}
	for g in _guests.values():
		if typeof(g) == TYPE_DICTIONARY:
			used[int((g as Dictionary).get("slot", 0))] = true
	for s in range(1, MAX_CLIENTS + 1):
		if not used.has(s):
			return s
	return -1


func _slot_of_peer(peer_id: int) -> int:
	var rec: Variant = _guests.get(peer_id, null)
	if typeof(rec) == TYPE_DICTIONARY:
		return int((rec as Dictionary).get("slot", 1))
	return 1


func pick_character(character_id: String) -> bool:
	if not in_session():
		return false
	if not is_instance_valid(Game) or not Game.select_character(character_id):
		return false
	if is_host():
		_broadcast_roster()
		return true
	if is_guest():
		_patch_local_roster_char(character_id)
		roster_changed.emit()
		if _handshake_ok:
			_rpc_pick_char.rpc_id(1, character_id)
	return true


func _patch_local_roster_char(character_id: String) -> void:
	if _roster.is_empty():
		return
	var slot: int = local_coop_slot if local_coop_slot > 0 else 1
	var next: Array = []
	for item in _roster:
		if typeof(item) != TYPE_DICTIONARY:
			next.append(item)
			continue
		var rec: Dictionary = (item as Dictionary).duplicate()
		if int(rec.get("slot", -1)) == slot:
			rec["char_id"] = character_id
		next.append(rec)
	_roster = next


func _broadcast_roster() -> void:
	if not is_host():
		return
	var arr: Array = get_roster()
	if _handshake_ok:
		_rpc_roster.rpc(game_mode, arr)
	roster_changed.emit()


@rpc("any_peer", "reliable")
func _rpc_pick_char(character_id: String) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _guests.has(sender):
		return
	if CharacterCatalog.find(character_id) == null:
		return
	var rec: Dictionary = _guests[sender]
	rec["char_id"] = character_id
	_guests[sender] = rec
	remote_character_id = character_id
	_broadcast_roster()


@rpc("any_peer", "reliable")
func _rpc_hello(proto: int, version_code: int, nick: String, char_id: String) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if proto != PROTO or version_code != _version_code():
		_rpc_reject.rpc_id(sender, "Atualize o APK — versões diferentes")
		handshake_rejected.emit("Atualize o APK — versões diferentes")
		call_deferred("_drop_peer", sender)
		return
	if in_stage:
		_rpc_reject.rpc_id(sender, "A fase já começou")
		call_deferred("_drop_peer", sender)
		return
	if _guests.size() >= GameMode.max_clients_for(game_mode):
		_rpc_reject.rpc_id(sender, "Sala cheia")
		call_deferred("_drop_peer", sender)
		return
	var slot: int = _next_free_slot()
	if slot < 1:
		_rpc_reject.rpc_id(sender, "Sala cheia")
		call_deferred("_drop_peer", sender)
		return
	var clean := Game.sanitize_player_name(nick)
	if clean.is_empty():
		clean = "Amigo"
	var cid: String = char_id if char_id != "" else "tanjiro"
	_guests[sender] = {"slot": slot, "nick": clean, "char_id": cid}
	remote_nick = clean
	remote_character_id = cid
	guest_peer_id = sender
	_handshake_ok = true
	_rpc_welcome.rpc_id(sender, _nick(), str(Game.current_character_id), slot, game_mode)
	_broadcast_roster()
	toast_requested.emit("Amigo entrou")
	peer_joined.emit(clean)


@rpc("authority", "reliable")
func _rpc_welcome(host_nick: String, host_char: String, assigned_slot: int = 1, mode_id: int = 0) -> void:
	if role != Role.GUEST:
		return
	remote_nick = Game.sanitize_player_name(host_nick)
	if remote_nick.is_empty():
		remote_nick = "Anfitrião"
	remote_character_id = host_char if host_char != "" else "tanjiro"
	if multiplayer.multiplayer_peer != null:
		guest_peer_id = multiplayer.get_unique_id()
	local_coop_slot = assigned_slot if assigned_slot > 0 else 1
	game_mode = mode_id
	_handshake_ok = true
	toast_requested.emit("Amigo entrou")
	peer_joined.emit(remote_nick)
	roster_changed.emit()


@rpc("authority", "reliable")
func _rpc_roster(mode_id: int, roster: Array) -> void:
	if role != Role.GUEST:
		return
	game_mode = mode_id
	_roster.clear()
	for item in roster:
		if typeof(item) == TYPE_DICTIONARY:
			_roster.append(item)
	roster_changed.emit()


@rpc("authority", "reliable")
func _rpc_reject(reason_pt: String) -> void:
	handshake_rejected.emit(reason_pt)
	join_failed.emit(reason_pt)
	close_session()


@rpc("authority", "reliable")
func _rpc_load_stage(path: String) -> void:
	if role != Role.GUEST:
		return
	if path.is_empty() or not ResourceLoader.exists(path):
		return
	in_stage = true
	stage_load.emit(path)
	call_deferred("_guest_go", path)


func _guest_go(path: String) -> void:
	if not is_inside_tree():
		return
	SceneRouter.go_to(path)


@rpc("authority", "reliable")
func _rpc_host_picking_stage() -> void:
	if role != Role.GUEST:
		return
	in_stage = false
	_input_t = 0.0
	_pending_just = 0
	_guest_onis.clear()
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	Engine.time_scale = 1.0
	call_deferred("_guest_go_hub")


func _guest_go_hub() -> void:
	if not is_inside_tree():
		return
	SceneRouter.to_hub()


@rpc("any_peer", "unreliable")
func _rpc_input(packed: PackedByteArray) -> void:
	if not multiplayer.is_server() or not in_stage:
		return
	if packed.size() < InputFrame.PACK_SIZE:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var slot: int = _slot_of_peer(sender)
	var pawn := _pawn(slot)
	if pawn != null and pawn.has_method("apply_input_frame"):
		pawn.call(
			"apply_input_frame",
			InputFrame.unpack_axis(packed),
			InputFrame.unpack_held(packed),
			InputFrame.unpack_just(packed),
			InputFrame.unpack_axis_y(packed)
		)
	if InputFrame.has_bit(InputFrame.unpack_just(packed), InputFrame.BIT_PAUSE):
		var sc := _stage_controller()
		if sc != null and sc.has_method("_show_pause_menu"):
			sc.call("_show_pause_menu")


@rpc("authority", "unreliable")
func _rpc_player_snaps(data: PackedByteArray) -> void:
	if role != Role.GUEST or not in_stage:
		return
	_apply_player_snaps(data)


@rpc("authority", "reliable")
func _rpc_spawn_oni(kind: String, x: float, y: float, net_id: int) -> void:
	if role != Role.GUEST:
		return
	_spawn_guest_oni(kind, x, y, net_id)


@rpc("authority", "unreliable")
func _rpc_oni_snaps(data: PackedByteArray) -> void:
	if role != Role.GUEST:
		return
	_apply_oni_snaps(data)


@rpc("authority", "reliable")
func _rpc_stage_cleared(stage_id: String, coins: int) -> void:
	if role != Role.GUEST:
		return
	stage_cleared_event.emit(stage_id, coins)


@rpc("authority", "reliable")
func _rpc_wipe() -> void:
	if role != Role.GUEST:
		return
	stage_wipe.emit()


@rpc("authority", "reliable")
func _rpc_waves_done() -> void:
	if role != Role.GUEST:
		return
	waves_unlocked.emit()


func mark_entered_stage() -> void:
	in_stage = true
	if is_host():
		_beacon.stop_broadcast()


func broadcast_spawn_oni(kind: String, x: float, y: float) -> int:
	var nid: int = _next_oni_id
	_next_oni_id += 1
	if _handshake_ok and is_host():
		_rpc_spawn_oni.rpc(kind, x, y, nid)
	return nid


func broadcast_stage_cleared(stage_id: String, coins: int) -> void:
	if is_host() and _handshake_ok:
		_rpc_stage_cleared.rpc(stage_id, coins)


func broadcast_wipe() -> void:
	if is_host() and _handshake_ok:
		_rpc_wipe.rpc()


func broadcast_waves_done() -> void:
	if is_host() and _handshake_ok:
		_rpc_waves_done.rpc()


func _broadcast_player_snaps() -> void:
	var buf := PackedByteArray()
	var nslots: int = maxi(hunter_count(), 2)
	for slot in range(nslots):
		var p := _pawn(slot)
		_append_player_snap(buf, p)
	if _handshake_ok:
		_rpc_player_snaps.rpc(buf)


func _append_player_snap(buf: PackedByteArray, p: Node) -> void:
	var off: int = buf.size()
	buf.resize(off + 20)
	if p == null or not (p is Node2D):
		buf.encode_float(off, 0.0)
		buf.encode_float(off + 4, 0.0)
		buf.encode_float(off + 8, 0.0)
		buf.encode_s8(off + 12, 1)
		buf.encode_u8(off + 13, 0)
		buf.encode_u16(off + 14, 0)
		buf.encode_u8(off + 16, 0)
		buf.encode_u8(off + 17, 0)
		buf.encode_u8(off + 18, 0)
		buf.encode_u8(off + 19, 0)
		return
	var body := p as CharacterBody2D
	buf.encode_float(off, body.global_position.x)
	buf.encode_float(off + 4, body.global_position.y)
	buf.encode_float(off + 8, body.velocity.x)
	var facing: float = 1.0
	if p.has_method("get_facing"):
		facing = float(p.call("get_facing"))
	buf.encode_s8(off + 12, 1 if facing >= 0.0 else -1)
	var st: int = 0
	if p.has_method("get_state"):
		st = int(p.call("get_state"))
	buf.encode_u8(off + 13, st)
	buf.encode_u16(off + 14, int(p.get("hp")))
	var breath_v: float = 0.0
	var breath_m: float = 100.0
	if p.has_method("get_pawn_breath"):
		breath_v = float(p.call("get_pawn_breath"))
		breath_m = float(p.call("get_pawn_breath_max"))
	buf.encode_u8(off + 16, clampi(int(round(breath_v)), 0, 255))
	buf.encode_u8(off + 17, clampi(int(round(breath_m)), 0, 255))
	buf.encode_u8(off + 18, 1 if p.get("is_local_pawn") == true else 0)
	buf.encode_u8(off + 19, 0)


func _apply_player_snaps(data: PackedByteArray) -> void:
	if data.size() < 20:
		return
	var nslots: int = data.size() / 20
	for slot in range(nslots):
		var off: int = slot * 20
		if off + 20 > data.size():
			break
		var p := _pawn(slot)
		if p == null or not p.has_method("apply_host_snap"):
			continue
		var pos := Vector2(data.decode_float(off), data.decode_float(off + 4))
		var vx: float = data.decode_float(off + 8)
		var facing: float = float(data.decode_s8(off + 12))
		var st: int = data.decode_u8(off + 13)
		var hp: int = data.decode_u16(off + 14)
		var breath_v: float = float(data.decode_u8(off + 16))
		var breath_m: float = float(data.decode_u8(off + 17))
		p.call("apply_host_snap", pos, vx, facing, st, hp, breath_v, breath_m)


func _broadcast_oni_snaps() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var buf := PackedByteArray()
	for n: Node in tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(n) or not (n is Node2D):
			continue
		var nid: int = int(n.get_meta("lan_net_id", 0))
		if nid <= 0:
			continue
		var off: int = buf.size()
		buf.resize(off + 15)
		buf.encode_u16(off, nid)
		buf.encode_float(off + 2, (n as Node2D).global_position.x)
		buf.encode_float(off + 6, (n as Node2D).global_position.y)
		buf.encode_u16(off + 10, int(n.get("hp")))
		buf.encode_u8(off + 12, int(n.get("state")))
		buf.encode_u8(off + 13, 0)
		buf.encode_u8(off + 14, 0)
	if _handshake_ok:
		_rpc_oni_snaps.rpc(buf)


func _apply_oni_snaps(data: PackedByteArray) -> void:
	var i := 0
	while i + 15 <= data.size():
		var nid: int = data.decode_u16(i)
		var pos := Vector2(data.decode_float(i + 2), data.decode_float(i + 6))
		var hp: int = data.decode_u16(i + 10)
		var st: int = data.decode_u8(i + 12)
		var oni: Node = _guest_onis.get(nid, null)
		if oni != null and is_instance_valid(oni):
			BossCommon.apply_lan_snap(oni, pos, hp, st)
		i += 15


func _spawn_guest_oni(kind: String, x: float, y: float, net_id: int) -> void:
	var scene: PackedScene = _oni_scene(kind)
	if scene == null:
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var oni: Node = scene.instantiate()
	oni.set("net_puppet", true)
	oni.set_meta("lan_net_id", net_id)
	tree.current_scene.add_child(oni)
	if oni is Node2D:
		(oni as Node2D).global_position = Vector2(x, y)
	_guest_onis[net_id] = oni


func _oni_scene(kind: String) -> PackedScene:
	match kind:
		"weak":
			return load("res://scenes/characters/enemies/oni_weak.tscn") as PackedScene
		"elite":
			return load("res://scenes/characters/enemies/oni_elite.tscn") as PackedScene
		"ranged":
			return load("res://scenes/characters/enemies/oni_ranged.tscn") as PackedScene
		"charger":
			return load("res://scenes/characters/enemies/oni_charger.tscn") as PackedScene
		"boss":
			return load("res://scenes/characters/enemies/oni_boss.tscn") as PackedScene
		"boss_fire":
			return load("res://scenes/characters/enemies/oni_boss_fire.tscn") as PackedScene
		"boss_dual":
			return load("res://scenes/characters/enemies/oni_boss_dual.tscn") as PackedScene
		"boss_castle":
			return load("res://scenes/characters/enemies/oni_boss_castle.tscn") as PackedScene
		"boss_final":
			return load("res://scenes/characters/enemies/oni_boss_final.tscn") as PackedScene
	return load("res://scenes/characters/enemies/oni_weak.tscn") as PackedScene


func _apply_leash() -> void:
	var p1 := _pawn(0)
	var p2 := _pawn(1)
	if p1 == null or p2 == null:
		return
	if not _pawn_alive(p1) or not _pawn_alive(p2):
		return
	var n: int = hunter_count()
	if n <= 2:
		var a := p1 as Node2D
		var b := p2 as Node2D
		var dx: float = b.global_position.x - a.global_position.x
		if absf(dx) <= LEASH_X:
			return
		if dx > 0.0:
			b.global_position.x = a.global_position.x + LEASH_X
		else:
			a.global_position.x = b.global_position.x + LEASH_X
		return
	var host_n := p1 as Node2D
	for slot in range(1, n):
		var p := _pawn(slot)
		if p == null or not _pawn_alive(p):
			continue
		var g := p as Node2D
		var dxx: float = g.global_position.x - host_n.global_position.x
		if absf(dxx) <= LEASH_X:
			continue
		if dxx > 0.0:
			g.global_position.x = host_n.global_position.x + LEASH_X
		else:
			g.global_position.x = host_n.global_position.x - LEASH_X


func _pawn(slot: int) -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group("player"):
		if int(n.get("coop_slot")) == slot:
			return n
	return null


func _pawn_alive(n: Node) -> bool:
	return BossCommon.is_player_alive(n)


func _stage_controller() -> Node:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var sc: Node = tree.current_scene
	if sc.has_method("report_player_death"):
		return sc
	return null


func _is_ipv4(s: String) -> bool:
	var parts: PackedStringArray = s.split(".")
	if parts.size() != 4:
		return false
	for p in parts:
		if not p.is_valid_int():
			return false
		var n: int = int(p)
		if n < 0 or n > 255:
			return false
	return true


func _in_boot() -> bool:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var path := str(tree.current_scene.scene_file_path)
	return (
		path.ends_with("splash_studio.tscn")
		or path.ends_with("loading.tscn")
		or path.ends_with("name_entry.tscn")
	)


func _start_host_relay_bridge() -> void:
	if not has_sala_meio() or not is_host() or room_code.is_empty():
		return
	_relay_bridge.start_host(_meio.host, _meio.relay_port(), room_code, ENET_PORT)


func _try_meio_announce(tell_if_off: bool) -> void:
	if _in_boot() or not has_sala_meio() or not is_host() or room_code.is_empty():
		return
	if tell_if_off:
		if not _meio.ping():
			if not _meio_pc_off_told:
				_meio_pc_off_told = true
				toast_requested.emit(MSG_PC_OFF)
			return
		_meio.announce(room_code, ENET_PORT, _nick(), _version_code())
		_start_host_relay_bridge()
		return
	_meio.send_fire({
		"op": "announce",
		"code": room_code,
		"port": ENET_PORT,
		"name": _nick(),
		"version_code": _version_code(),
	})


func _try_meio_lookup() -> void:
	if _listening_for_code.is_empty():
		return
	if not has_sala_meio():
		return
	if not _meio.ping():
		if not _meio_pc_off_told:
			_meio_pc_off_told = true
			toast_requested.emit(MSG_PC_OFF)
		return
	var reply: Dictionary = _meio.lookup(_listening_for_code)
	if str(reply.get("op", "")) != "found":
		return
	var code := RoomCode.normalize(str(reply.get("code", "")))
	if code != _listening_for_code:
		return
	var relay: int = int(reply.get("relay_port", _meio.relay_port()))
	if relay <= 0:
		relay = _meio.relay_port()
	var local_port: int = _relay_bridge.start_guest(_meio.host, relay, code)
	if local_port < 1:
		toast_requested.emit("Não deu para abrir o caminho da sala")
		return
	_listening_for_code = ""
	_beacon.stop_listen()
	_connect_enet("127.0.0.1", local_port)


func _poll_meio_calls() -> void:
	if _in_boot() or not has_sala_meio():
		return
	var fid := _friend_id()
	_meio.presence(_nick(), room_code if is_host() else "", fid)
	var inbox: Dictionary = _meio.poll_calls(_nick(), fid)
	_apply_meio_inbox(inbox)
	for reply: Dictionary in _meio.drain():
		_apply_meio_inbox(reply)


func _apply_meio_inbox(reply: Dictionary) -> void:
	if str(reply.get("op", "")) != "inbox":
		return
	var calls: Variant = reply.get("calls", [])
	if calls is Array:
		for item in calls:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var d: Dictionary = item
			var from_nick := Game.sanitize_player_name(str(d.get("from", "")))
			if from_nick.is_empty():
				continue
			toast_requested.emit("%s te chamou" % from_nick)
	var invites: Variant = reply.get("invites", [])
	if not invites is Array:
		return
	for item in invites:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var inv: Dictionary = item
		var kind := str(inv.get("kind", ""))
		var from_nick := Game.sanitize_player_name(str(inv.get("from", "")))
		var from_id := str(inv.get("from_id", ""))
		if kind == "friend":
			if from_nick.is_empty():
				from_nick = "Caçador"
			var fresh := false
			if is_instance_valid(Game):
				fresh = Game.add_incoming_invite(from_id, from_nick)
			if fresh:
				toast_requested.emit("%s quer ser amigo" % from_nick)
		elif kind == "friend_ok":
			if from_nick.is_empty():
				from_nick = "Amigo"
			if is_instance_valid(Game):
				Game.add_friend(from_nick, from_id)
			toast_requested.emit("%s aceitou" % from_nick)
		elif kind == "room":
			var code := RoomCode.normalize(str(inv.get("code", "")))
			if not RoomCode.is_valid(code):
				continue
			if from_nick.is_empty():
				from_nick = "Amigo"
			toast_requested.emit("%s te chamou pra sala" % from_nick)
			room_invite_received.emit(from_nick, code)
