class_name EnetRelayBridge
extends RefCounted
## Ponte UDP casa↔casa: os dois celulares só saem pra VPS (NAT não precisa abrir porta).
## Host: VPS ↔ 127.0.0.1:ENet. Guest: ENet client ↔ 127.0.0.1:ponte ↔ VPS.
## 1 byte de slot no trecho host↔VPS. Sem SceneTree.

const MAGIC := "HASHIRA_MEIO"
const PROTO := 1
const KEEPALIVE_SEC := 5.0
const ENET_HOST := "127.0.0.1"

var active: bool = false
var local_guest_port: int = 0

var _role: String = ""
var _code: String = ""
var _enet_port: int = 17777
var _wan: PacketPeerUDP
var _guest_lan: PacketPeerUDP
var _guest_peer_ip: String = ""
var _guest_peer_port: int = 0
var _host_lan: Dictionary = {} # slot:int -> PacketPeerUDP
var _keep_t: float = 0.0


func start_host(vps: String, relay_port: int, room_code: String, enet_port: int) -> bool:
	stop()
	var n := RoomCode.normalize(room_code)
	if not RoomCode.is_valid(n) or vps.strip_edges().is_empty() or relay_port < 1:
		return false
	_role = "host"
	_code = n
	_enet_port = enet_port if enet_port > 0 else 17777
	if not _open_wan(vps, relay_port):
		stop()
		return false
	active = true
	_keep_t = 0.0
	_send_ctrl("relay_bind")
	return true


func start_guest(vps: String, relay_port: int, room_code: String) -> int:
	stop()
	var n := RoomCode.normalize(room_code)
	if not RoomCode.is_valid(n) or vps.strip_edges().is_empty() or relay_port < 1:
		return 0
	_role = "guest"
	_code = n
	_guest_lan = PacketPeerUDP.new()
	if _guest_lan.bind(0, ENET_HOST) != OK:
		stop()
		return 0
	local_guest_port = _guest_lan.get_local_port()
	if local_guest_port < 1:
		stop()
		return 0
	if not _open_wan(vps, relay_port):
		stop()
		return 0
	active = true
	_keep_t = 0.0
	_send_ctrl("relay_join")
	return local_guest_port


func pump(delta: float) -> void:
	if not active:
		return
	_keep_t += delta
	if _keep_t >= KEEPALIVE_SEC:
		_keep_t = 0.0
		if _role == "host":
			_send_ctrl("relay_bind")
		elif _role == "guest":
			_send_ctrl("relay_join")
	_pump_wan()
	if _role == "host":
		_pump_host_lan()
	elif _role == "guest":
		_pump_guest_lan()


func stop() -> void:
	active = false
	_role = ""
	_code = ""
	local_guest_port = 0
	_guest_peer_ip = ""
	_guest_peer_port = 0
	_keep_t = 0.0
	if _wan != null:
		_wan.close()
		_wan = null
	if _guest_lan != null:
		_guest_lan.close()
		_guest_lan = null
	for k in _host_lan.keys():
		var s: PacketPeerUDP = _host_lan[k] as PacketPeerUDP
		if s != null:
			s.close()
	_host_lan.clear()


func _open_wan(vps: String, relay_port: int) -> bool:
	_wan = PacketPeerUDP.new()
	if _wan.bind(0, "0.0.0.0") != OK:
		_wan = null
		return false
	if _wan.set_dest_address(vps.strip_edges(), relay_port) != OK:
		_wan.close()
		_wan = null
		return false
	return true


func _send_ctrl(op: String) -> void:
	if _wan == null or _code.is_empty():
		return
	var raw: PackedByteArray = JSON.stringify({
		"magic": MAGIC,
		"proto": PROTO,
		"op": op,
		"code": _code,
	}).to_utf8_buffer()
	if raw.is_empty():
		return
	_wan.put_packet(raw)


func _pump_wan() -> void:
	if _wan == null:
		return
	while _wan.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _wan.get_packet()
		if pkt.is_empty():
			continue
		if pkt[0] == 0x7B:
			continue
		if _role == "host":
			if pkt.size() < 2:
				continue
			var slot: int = int(pkt[0])
			if slot < 1 or slot > 3:
				continue
			var lan := _ensure_host_lan(slot)
			if lan != null:
				lan.put_packet(pkt.slice(1))
		elif _role == "guest" and _guest_lan != null:
			if _guest_peer_port > 0:
				_guest_lan.set_dest_address(_guest_peer_ip, _guest_peer_port)
			_guest_lan.put_packet(pkt)


func _pump_host_lan() -> void:
	for k in _host_lan.keys():
		var slot: int = int(k)
		var lan: PacketPeerUDP = _host_lan[k] as PacketPeerUDP
		if lan == null:
			continue
		while lan.get_available_packet_count() > 0:
			var pkt: PackedByteArray = lan.get_packet()
			if pkt.is_empty() or _wan == null:
				continue
			var wrapped := PackedByteArray()
			wrapped.append(slot)
			wrapped.append_array(pkt)
			_wan.put_packet(wrapped)


func _pump_guest_lan() -> void:
	if _guest_lan == null or _wan == null:
		return
	while _guest_lan.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _guest_lan.get_packet()
		var ip := _guest_lan.get_packet_ip()
		var port: int = _guest_lan.get_packet_port()
		if not ip.is_empty() and port > 0:
			_guest_peer_ip = ip
			_guest_peer_port = port
		if not pkt.is_empty():
			_wan.put_packet(pkt)


func _ensure_host_lan(slot: int) -> PacketPeerUDP:
	if _host_lan.has(slot):
		return _host_lan[slot] as PacketPeerUDP
	var lan := PacketPeerUDP.new()
	if lan.bind(0, ENET_HOST) != OK:
		return null
	if lan.set_dest_address(ENET_HOST, _enet_port) != OK:
		lan.close()
		return null
	_host_lan[slot] = lan
	return lan
