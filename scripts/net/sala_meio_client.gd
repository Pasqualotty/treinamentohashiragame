class_name SalaMeioClient
extends RefCounted
## Cliente UDP do computador da sala (saída 3a). Sem Firebase, sem save de IP.

const MAGIC := "HASHIRA_MEIO"
const PROTO := 1
const DEFAULT_PORT := 17779
const MAX_BYTES := 512
const PING_MS := 500
const LOOKUP_MS := 800


var host: String = ""
var port: int = DEFAULT_PORT
var _sock: PacketPeerUDP


func is_configured() -> bool:
	return not host.strip_edges().is_empty() and port > 0 and port <= 65535


func clear() -> void:
	host = ""
	port = DEFAULT_PORT
	_close_sock()


func set_endpoint(raw: String) -> bool:
	_close_sock()
	var parsed: Dictionary = parse_endpoint(raw)
	if parsed.is_empty():
		clear()
		return raw.strip_edges().is_empty()
	host = str(parsed.get("host", ""))
	port = int(parsed.get("port", DEFAULT_PORT))
	return is_configured()


func endpoint_text() -> String:
	if not is_configured():
		return ""
	return "%s:%d" % [host, port]


func relay_port() -> int:
	if not is_configured():
		return 0
	return port + 1


static func parse_endpoint(raw: String) -> Dictionary:
	var s := raw.strip_edges()
	if s.is_empty():
		return {}
	if " " in s or "\n" in s or "\t" in s:
		return {}
	if s.begins_with("["):
		return {}
	var h := s
	var p: int = DEFAULT_PORT
	var colon: int = s.rfind(":")
	if colon >= 0:
		if colon == 0 or colon == s.length() - 1:
			return {}
		h = s.substr(0, colon)
		var ps := s.substr(colon + 1)
		if not ps.is_valid_int():
			return {}
		p = int(ps)
	if h.is_empty() or h == "." or h.contains("/"):
		return {}
	if p < 1 or p > 65535:
		return {}
	return {"host": h, "port": p}


func ping() -> bool:
	var reply: Dictionary = request({"op": "ping"}, PING_MS)
	return str(reply.get("op", "")) == "pong"


func announce(code: String, enet_port: int, nick: String, version_code: int) -> Dictionary:
	return request({
		"op": "announce",
		"code": code,
		"port": enet_port,
		"name": nick,
		"version_code": version_code,
	}, LOOKUP_MS)


func lookup(code: String) -> Dictionary:
	return request({"op": "lookup", "code": code}, LOOKUP_MS)


func presence(nick: String, code: String = "") -> Dictionary:
	return request({"op": "presence", "name": nick, "code": code}, PING_MS)


func call_nick(from_nick: String, to_nick: String) -> Dictionary:
	return request({
		"op": "call",
		"from": from_nick,
		"to": to_nick,
	}, LOOKUP_MS)


func poll_calls(nick: String) -> Dictionary:
	return request({"op": "poll", "name": nick}, PING_MS)


func send_fire(body: Dictionary) -> bool:
	if not _ensure_sock():
		return false
	var raw := _encode(body)
	if raw.is_empty():
		return false
	return _sock.put_packet(raw) == OK


func drain() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _sock == null:
		return out
	while _sock.get_available_packet_count() > 0:
		var parsed: Dictionary = _parse_reply(_sock.get_packet())
		if not parsed.is_empty():
			out.append(parsed)
	return out


func request(body: Dictionary, timeout_ms: int) -> Dictionary:
	if not is_configured():
		return {}
	var sock := PacketPeerUDP.new()
	var bind_err := sock.bind(0, "0.0.0.0")
	if bind_err != OK:
		sock.close()
		return {}
	var dest_err := sock.set_dest_address(host, port)
	if dest_err != OK:
		sock.close()
		return {}
	var raw := _encode(body)
	if raw.is_empty():
		sock.close()
		return {}
	if sock.put_packet(raw) != OK:
		sock.close()
		return {}
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < timeout_ms:
		OS.delay_msec(15)
		if sock.get_available_packet_count() <= 0:
			continue
		var pkt: PackedByteArray = sock.get_packet()
		sock.close()
		return _parse_reply(pkt)
	sock.close()
	return {}


func _encode(body: Dictionary) -> PackedByteArray:
	var msg: Dictionary = body.duplicate()
	msg["magic"] = MAGIC
	msg["proto"] = PROTO
	var txt := JSON.stringify(msg)
	var raw: PackedByteArray = txt.to_utf8_buffer()
	if raw.is_empty() or raw.size() > MAX_BYTES:
		return PackedByteArray()
	return raw


func _ensure_sock() -> bool:
	if not is_configured():
		return false
	if _sock != null:
		return true
	_sock = PacketPeerUDP.new()
	if _sock.bind(0, "0.0.0.0") != OK:
		_close_sock()
		return false
	if _sock.set_dest_address(host, port) != OK:
		_close_sock()
		return false
	return true


func _close_sock() -> void:
	if _sock != null:
		_sock.close()
		_sock = null


func _parse_reply(pkt: PackedByteArray) -> Dictionary:
	if pkt.is_empty() or pkt.size() > MAX_BYTES:
		return {}
	var parsed: Variant = JSON.parse_string(pkt.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	if str(d.get("magic", "")) != MAGIC:
		return {}
	if int(d.get("proto", 0)) != PROTO:
		return {}
	return d
