class_name SalaMeioClient
extends RefCounted
## Cliente da sala da estrela. UDP primeiro; HTTP 8080 / TCP se o UDP morrer.
## Host baked em ProjectSettings hashira/sala_host. Sem save de IP.

const MAGIC := "HASHIRA_MEIO"
const PROTO := 1
const DEFAULT_PORT := 17779
const HTTP_PORT := 8080
const MAX_BYTES := 512
const PING_MS := 500
const LOOKUP_MS := 800
const SETTING_HOST := "hashira/sala_host"
const SETTING_HTTP := "hashira/sala_http_port"


var host: String = ""
var port: int = DEFAULT_PORT
var http_port: int = HTTP_PORT
var _sock: PacketPeerUDP
var _via_http: bool = false


static func baked_host() -> String:
	if not ProjectSettings.has_setting(SETTING_HOST):
		return ""
	return str(ProjectSettings.get_setting(SETTING_HOST)).strip_edges()


static func baked_http_port() -> int:
	if ProjectSettings.has_setting(SETTING_HTTP):
		var p: int = int(ProjectSettings.get_setting(SETTING_HTTP))
		if p > 0 and p <= 65535:
			return p
	return HTTP_PORT


func apply_baked() -> bool:
	var raw := baked_host()
	if raw.is_empty():
		return false
	http_port = baked_http_port()
	return set_endpoint(raw)


func is_configured() -> bool:
	return not host.strip_edges().is_empty() and port > 0 and port <= 65535


func uses_http() -> bool:
	return _via_http


func clear() -> void:
	host = ""
	port = DEFAULT_PORT
	http_port = HTTP_PORT
	_via_http = false
	_close_sock()


func set_endpoint(raw: String) -> bool:
	_close_sock()
	_via_http = false
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


func presence(nick: String, code: String = "", friend_id: String = "") -> Dictionary:
	var body: Dictionary = {"op": "presence", "name": nick, "code": code}
	if FriendCode.is_valid(friend_id):
		body["friend_id"] = FriendCode.normalize(friend_id)
	return request(body, PING_MS)


func call_nick(from_nick: String, to_nick: String) -> Dictionary:
	return request({
		"op": "call",
		"from": from_nick,
		"to": to_nick,
	}, LOOKUP_MS)


func poll_calls(nick: String, friend_id: String = "") -> Dictionary:
	var body: Dictionary = {"op": "poll", "name": nick}
	if FriendCode.is_valid(friend_id):
		body["friend_id"] = FriendCode.normalize(friend_id)
	return request(body, PING_MS)


func friend_invite(from_id: String, from_name: String, to_id: String) -> Dictionary:
	return request({
		"op": "friend_invite",
		"from_id": FriendCode.normalize(from_id),
		"from_name": from_name,
		"to_id": FriendCode.normalize(to_id),
	}, LOOKUP_MS)


func friend_accept(my_id: String, my_name: String, their_id: String) -> Dictionary:
	return request({
		"op": "friend_accept",
		"my_id": FriendCode.normalize(my_id),
		"my_name": my_name,
		"their_id": FriendCode.normalize(their_id),
	}, LOOKUP_MS)


func friend_decline(my_id: String, their_id: String) -> Dictionary:
	return request({
		"op": "friend_decline",
		"my_id": FriendCode.normalize(my_id),
		"their_id": FriendCode.normalize(their_id),
	}, LOOKUP_MS)


func room_invite(from_id: String, from_name: String, to_id: String, room_code: String) -> Dictionary:
	return request({
		"op": "room_invite",
		"from_id": FriendCode.normalize(from_id),
		"from_name": from_name,
		"to_id": FriendCode.normalize(to_id),
		"code": RoomCode.normalize(room_code),
	}, LOOKUP_MS)


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
	var udp: Dictionary = _request_udp(body, timeout_ms)
	if not udp.is_empty():
		_via_http = false
		return udp
	var http: Dictionary = _request_http(body, timeout_ms)
	if not http.is_empty():
		_via_http = true
		return http
	var tcp: Dictionary = _request_tcp(body, timeout_ms)
	if not tcp.is_empty():
		_via_http = true
		return tcp
	return {}


func _request_udp(body: Dictionary, timeout_ms: int) -> Dictionary:
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


func _request_http(body: Dictionary, timeout_ms: int) -> Dictionary:
	var raw := _encode(body)
	if raw.is_empty():
		return {}
	var http := HTTPClient.new()
	if http.connect_to_host(host, http_port) != OK:
		return {}
	var t0: int = Time.get_ticks_msec()
	while (
		http.get_status() == HTTPClient.STATUS_CONNECTING
		or http.get_status() == HTTPClient.STATUS_RESOLVING
	):
		if Time.get_ticks_msec() - t0 >= timeout_ms:
			http.close()
			return {}
		http.poll()
		OS.delay_msec(15)
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		http.close()
		return {}
	var headers := PackedStringArray(["Content-Type: application/json"])
	if http.request(HTTPClient.METHOD_POST, "/sala", headers, raw.get_string_from_utf8()) != OK:
		http.close()
		return {}
	var buf := PackedByteArray()
	while Time.get_ticks_msec() - t0 < timeout_ms:
		http.poll()
		var st: int = http.get_status()
		if st == HTTPClient.STATUS_BODY:
			var chunk: PackedByteArray = http.read_response_body_chunk()
			if chunk.size() > 0:
				buf.append_array(chunk)
		elif st == HTTPClient.STATUS_CONNECTED:
			if not buf.is_empty():
				break
		elif (
			st != HTTPClient.STATUS_REQUESTING
			and st != HTTPClient.STATUS_BODY
		):
			break
		OS.delay_msec(15)
	http.close()
	return _parse_reply(buf)


func _request_tcp(body: Dictionary, timeout_ms: int) -> Dictionary:
	var raw := _encode(body)
	if raw.is_empty():
		return {}
	var tcp := StreamPeerTCP.new()
	if tcp.connect_to_host(host, port) != OK:
		return {}
	var t0: int = Time.get_ticks_msec()
	while tcp.get_status() == StreamPeerTCP.STATUS_CONNECTING:
		tcp.poll()
		if Time.get_ticks_msec() - t0 >= timeout_ms:
			tcp.disconnect_from_host()
			return {}
		OS.delay_msec(15)
	if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		tcp.disconnect_from_host()
		return {}
	var payload: PackedByteArray = raw.duplicate()
	payload.append(10)
	tcp.put_data(payload)
	var got := PackedByteArray()
	while Time.get_ticks_msec() - t0 < timeout_ms:
		tcp.poll()
		var avail: int = tcp.get_available_bytes()
		if avail > 0:
			var pair: Array = tcp.get_partial_data(avail)
			if int(pair[0]) == OK:
				got.append_array(pair[1])
			if got.find(10) >= 0:
				break
		OS.delay_msec(15)
	tcp.disconnect_from_host()
	if got.is_empty():
		return {}
	var cut: int = got.find(10)
	if cut >= 0:
		got = got.slice(0, cut)
	return _parse_reply(got)


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
