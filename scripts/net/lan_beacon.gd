class_name LanBeacon
extends RefCounted
## Beacon UDP na LAN. Código filtra o pacote; o IP vem no datagrama, não no save.

const MAGIC := "HASHIRA"
const PORT := 17778
const PROTO := 1
const MAX_BYTES := 512
const BROADCAST_ADDR := "255.255.255.255"


var _send: PacketPeerUDP
var _listen: PacketPeerUDP
var _payload: PackedByteArray = PackedByteArray()


func start_broadcast(code: String, enet_port: int, nick: String, version_code: int) -> bool:
	stop_broadcast()
	var body := {
		"magic": MAGIC,
		"proto": PROTO,
		"code": code,
		"port": enet_port,
		"name": nick,
		"version_code": version_code,
	}
	var txt := JSON.stringify(body)
	if txt.to_utf8_buffer().size() > MAX_BYTES:
		return false
	_payload = txt.to_utf8_buffer()
	_send = PacketPeerUDP.new()
	_send.set_broadcast_enabled(true)
	var err := _send.set_dest_address(BROADCAST_ADDR, PORT)
	if err != OK:
		_send = null
		return false
	return true


func pulse() -> void:
	if _send == null or _payload.is_empty():
		return
	_send.put_packet(_payload)


func start_listen() -> bool:
	stop_listen()
	_listen = PacketPeerUDP.new()
	_listen.set_broadcast_enabled(true)
	var err := _listen.bind(PORT)
	if err != OK:
		_listen = null
		return false
	return true


## Pacotes válidos (magic + proto). Sem dump de IP no retorno logável.
func poll_matches(want_code: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _listen == null:
		return out
	var want := RoomCode.normalize(want_code)
	while _listen.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _listen.get_packet()
		if pkt.size() > MAX_BYTES or pkt.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(pkt.get_string_from_utf8())
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = parsed
		if str(d.get("magic", "")) != MAGIC:
			continue
		if int(d.get("proto", 0)) != PROTO:
			continue
		var code := RoomCode.normalize(str(d.get("code", "")))
		if code != want:
			continue
		var packet_ip: String = _listen.get_packet_ip()
		var port: int = int(d.get("port", 17777))
		out.append({
			"code": code,
			"port": port,
			"name": str(d.get("name", "")),
			"version_code": int(d.get("version_code", 0)),
			"ip": packet_ip,
		})
	return out


func stop_broadcast() -> void:
	if _send != null:
		_send.close()
		_send = null
	_payload = PackedByteArray()


func stop_listen() -> void:
	if _listen != null:
		_listen.close()
		_listen = null


func stop() -> void:
	stop_broadcast()
	stop_listen()
