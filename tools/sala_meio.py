#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Sala da estrela — celulares se acham sem ligar PC.

UDP (17779) + TCP (17779) + HTTP (8080) + relay ENet (17780).
O APK já aponta pra cá. PC local é só reserva de dev.

Sem Firebase, sem Play Games, sem conta.
Sala caiu: o jogo ainda abre; MULTIPLAYER / ENTRAR avisam em português.

Uso:
  python tools/sala_meio.py
  python tools/sala_meio.py --port 17779 --http-port 8080 --bind 0.0.0.0
"""
from __future__ import annotations

import argparse
import json
import select
import socket
import sys
import time

MAGIC = "HASHIRA_MEIO"
PROTO = 1
DEFAULT_PORT = 17779
DEFAULT_HTTP_PORT = 8080
MAX_BYTES = 512
REPLY_MAX = 2048
HTTP_MAX = 4096
RELAY_MAX = 4096
ROOM_TTL = 90.0
PRESENCE_TTL = 35.0
CALL_TTL = 45.0
FRIEND_INVITE_TTL = 86400.0
ROOM_INVITE_TTL = 90.0
CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
NICK_MAX = 24
FRIEND_LEN = 8
INBOX_CAP = 6


def _now() -> float:
    return time.monotonic()


def _normalize_code(raw: object) -> str:
    s = str(raw or "").strip().replace(" ", "").upper()
    if len(s) != 6:
        return ""
    if any(c not in CHARSET for c in s):
        return ""
    return s


def _normalize_friend_id(raw: object) -> str:
    s = str(raw or "").strip().replace(" ", "").upper()
    if len(s) != FRIEND_LEN:
        return ""
    if any(c not in CHARSET for c in s):
        return ""
    return s


def _sanitize_nick(raw: object) -> str:
    s = str(raw or "").strip()
    out = []
    for ch in s:
        o = ord(ch)
        if o < 32 or (0x7F <= o <= 0x9F):
            continue
        out.append(ch)
    clean = " ".join("".join(out).split())
    if len(clean) > NICK_MAX:
        clean = clean[:NICK_MAX].strip()
    return clean


def _reply(op: str, **extra) -> bytes:
    body = {"magic": MAGIC, "proto": PROTO, "op": op}
    body.update(extra)
    raw = json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    if len(raw) > REPLY_MAX:
        return b""
    return raw


def _http_response(body: bytes, status: int = 200) -> bytes:
    reason = {200: "OK", 204: "No Content", 400: "Bad Request", 404: "Not Found"}.get(status, "OK")
    head = (
        "HTTP/1.1 %d %s\r\n"
        "Content-Type: application/json\r\n"
        "Content-Length: %d\r\n"
        "Connection: close\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "\r\n"
    ) % (status, reason, len(body))
    return head.encode("ascii") + body


class SalaMeio:
    def __init__(self, bind: str, port: int, relay_port: int, http_port: int = DEFAULT_HTTP_PORT) -> None:
        self.bind = bind
        self.port = port
        self.relay_port = relay_port
        self.http_port = http_port
        self.ctrl = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.ctrl.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.ctrl.bind((bind, port))
        self.relay = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.relay.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.relay.bind((bind, relay_port))
        self.tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.tcp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.tcp.bind((bind, port))
        self.tcp.listen(16)
        self.tcp.setblocking(False)
        self.http = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.http.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            self.http.bind((bind, http_port))
            self.http.listen(16)
            self.http.setblocking(False)
        except OSError as exc:
            print("HTTP %d ocupada — seguindo só UDP/TCP (%s)" % (http_port, exc), flush=True)
            try:
                self.http.close()
            except OSError:
                pass
            self.http = None
            self.http_port = 0
        self.rooms: dict[str, dict] = {}
        self.presence: dict[str, dict] = {}
        self.presence_ids: dict[str, dict] = {}
        self.calls: dict[str, list[dict]] = {}
        self.friend_pending: dict[str, list[dict]] = {}
        self.friendships: dict[str, set[str]] = {}
        self.invites: dict[str, list[dict]] = {}
        self.relay_peers: dict[tuple[str, int], dict] = {}
        self.relay_host: tuple[str, int] | None = None
        self.relay_guest: tuple[str, int] | None = None

    def close(self) -> None:
        for sock in (self.ctrl, self.relay, self.tcp, self.http):
            if sock is None:
                continue
            try:
                sock.close()
            except OSError:
                pass

    def _expire(self) -> None:
        t = _now()
        dead_rooms = [k for k, v in self.rooms.items() if t - float(v["ts"]) > ROOM_TTL]
        for k in dead_rooms:
            self.rooms.pop(k, None)
        dead_nicks = [k for k, v in self.presence.items() if t - float(v["ts"]) > PRESENCE_TTL]
        for k in dead_nicks:
            self.presence.pop(k, None)
        dead_ids = [k for k, v in self.presence_ids.items() if t - float(v["ts"]) > PRESENCE_TTL]
        for k in dead_ids:
            self.presence_ids.pop(k, None)
        for nick, items in list(self.calls.items()):
            kept = [c for c in items if t - float(c["ts"]) <= CALL_TTL]
            if kept:
                self.calls[nick] = kept
            else:
                self.calls.pop(nick, None)
        for fid, items in list(self.friend_pending.items()):
            kept = [c for c in items if t - float(c["ts"]) <= FRIEND_INVITE_TTL]
            if kept:
                self.friend_pending[fid] = kept
            else:
                self.friend_pending.pop(fid, None)
        for fid, items in list(self.invites.items()):
            kept = [c for c in items if t - float(c["ts"]) <= float(c.get("ttl") or ROOM_INVITE_TTL)]
            if kept:
                self.invites[fid] = kept
            else:
                self.invites.pop(fid, None)
        dead_peers = []
        for addr, rec in self.relay_peers.items():
            code = str(rec.get("code") or "")
            if code not in self.rooms:
                dead_peers.append(addr)
        for addr in dead_peers:
            self.relay_peers.pop(addr, None)

    def handle_ctrl(self, data: bytes, addr: tuple[str, int]) -> bytes:
        self._expire()
        if not data or len(data) > MAX_BYTES:
            return b""
        try:
            parsed = json.loads(data.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return b""
        if not isinstance(parsed, dict):
            return b""
        try:
            proto = int(parsed.get("proto") or 0)
        except (TypeError, ValueError):
            return b""
        if parsed.get("magic") != MAGIC or proto != PROTO:
            return b""
        op = str(parsed.get("op") or "")
        src_ip = addr[0]
        if op == "ping":
            return _reply("pong")
        if op == "announce":
            return self._announce(parsed, src_ip)
        if op == "lookup":
            return self._lookup(parsed)
        if op == "presence":
            return self._presence(parsed, src_ip)
        if op == "call":
            return self._call(parsed)
        if op == "poll":
            return self._poll(parsed)
        if op == "friend_invite":
            return self._friend_invite(parsed)
        if op == "friend_accept":
            return self._friend_accept(parsed)
        if op == "friend_decline":
            return self._friend_decline(parsed)
        if op == "room_invite":
            return self._room_invite(parsed)
        if op == "friends_status":
            return self._friends_status(parsed)
        if op == "relay_bind":
            return self._relay_bind(parsed, addr)
        if op == "relay_join":
            return self._relay_join(parsed, addr)
        return _reply("error", reason="op")

    def handle_http(self, data: bytes, addr: tuple[str, int]) -> bytes:
        if not data or len(data) > HTTP_MAX:
            return _http_response(b"", 400)
        head, sep, rest = data.partition(b"\r\n\r\n")
        if not sep:
            return _http_response(b"", 400)
        first = head.split(b"\r\n", 1)[0].decode("ascii", "replace")
        parts = first.split()
        if len(parts) < 2:
            return _http_response(b"", 400)
        method = parts[0].upper()
        path = parts[1].split("?", 1)[0]
        if method == "GET" and path in ("/ping", "/health"):
            return _http_response(_reply("pong"))
        if method == "POST" and path in ("/sala", "/", "/ctrl"):
            body = self.handle_ctrl(rest.strip() or b"", addr)
            if not body:
                return _http_response(b"", 204)
            return _http_response(body)
        return _http_response(b"", 404)

    def handle_tcp_line(self, data: bytes, addr: tuple[str, int]) -> bytes:
        line = data.strip().split(b"\n", 1)[0].strip()
        reply = self.handle_ctrl(line, addr)
        if not reply:
            return b""
        return reply + b"\n"

    def _announce(self, parsed: dict, src_ip: str) -> bytes:
        code = _normalize_code(parsed.get("code"))
        nick = _sanitize_nick(parsed.get("name"))
        if not code:
            return _reply("error", reason="code")
        if not nick:
            nick = "Anfitrião"
        try:
            enet_port = int(parsed.get("port") or 17777)
        except (TypeError, ValueError):
            enet_port = 17777
        if enet_port < 1 or enet_port > 65535:
            enet_port = 17777
        try:
            version_code = int(parsed.get("version_code") or 0)
        except (TypeError, ValueError):
            version_code = 0
        prev = self.rooms.get(code, {})
        self.rooms[code] = {
            "ip": src_ip,
            "port": enet_port,
            "name": nick,
            "version_code": version_code,
            "ts": _now(),
            "wan_host": prev.get("wan_host"),
            "wan_guests": prev.get("wan_guests") or {},
        }
        friend_id = _normalize_friend_id(parsed.get("friend_id"))
        self.presence[nick] = {
            "ts": _now(),
            "code": code,
            "ip": src_ip,
            "friend_id": friend_id,
        }
        if friend_id:
            self.presence_ids[friend_id] = {
                "ts": _now(),
                "name": nick,
                "code": code,
                "ip": src_ip,
            }
        host_tuple = (src_ip, enet_port)
        if self.relay_host != host_tuple:
            self.relay_guest = None
        self.relay_host = host_tuple
        return _reply(
            "announced",
            code=code,
            relay_port=self.relay_port,
        )

    def _lookup(self, parsed: dict) -> bytes:
        code = _normalize_code(parsed.get("code"))
        if not code:
            return _reply("error", reason="code")
        room = self.rooms.get(code)
        if room is None:
            return _reply("missing", code=code)
        self.relay_host = (str(room["ip"]), int(room["port"]))
        return _reply(
            "found",
            code=code,
            ip=str(room["ip"]),
            port=int(room["port"]),
            name=str(room["name"]),
            version_code=int(room["version_code"]),
            relay_port=self.relay_port,
        )

    def _presence(self, parsed: dict, src_ip: str) -> bytes:
        nick = _sanitize_nick(parsed.get("name"))
        if not nick:
            return _reply("error", reason="name")
        code = _normalize_code(parsed.get("code"))
        friend_id = _normalize_friend_id(parsed.get("friend_id"))
        prev = self.presence.get(nick, {})
        self.presence[nick] = {
            "ts": _now(),
            "code": code or str(prev.get("code") or ""),
            "ip": src_ip,
            "friend_id": friend_id or str(prev.get("friend_id") or ""),
        }
        if friend_id:
            self.presence_ids[friend_id] = {
                "ts": _now(),
                "name": nick,
                "code": code or str(prev.get("code") or ""),
                "ip": src_ip,
            }
        return _reply("ok", name=nick)

    def _call(self, parsed: dict) -> bytes:
        src = _sanitize_nick(parsed.get("from"))
        dst = _sanitize_nick(parsed.get("to"))
        if not src or not dst:
            return _reply("error", reason="name")
        target = self.presence.get(dst)
        if target is None:
            return _reply("offline", to=dst)
        code = str(self.presence.get(src, {}).get("code") or "")
        if not code:
            for c, room in self.rooms.items():
                if str(room.get("name")) == src:
                    code = c
                    break
        bucket = self.calls.setdefault(dst, [])
        bucket.append({"from": src, "code": code, "ts": _now()})
        return _reply("called", to=dst, code=code)

    def _poll(self, parsed: dict) -> bytes:
        nick = _sanitize_nick(parsed.get("name"))
        if not nick:
            return _reply("error", reason="name")
        friend_id = _normalize_friend_id(parsed.get("friend_id"))
        items = self.calls.pop(nick, [])
        out = [{"from": str(i.get("from") or "")} for i in items]
        invites: list[dict] = []
        if friend_id:
            pending = self.friend_pending.get(friend_id, [])
            for i in pending[:INBOX_CAP]:
                invites.append({
                    "kind": "friend",
                    "from": str(i.get("from_name") or ""),
                    "from_id": str(i.get("from_id") or ""),
                })
            extra = self.invites.pop(friend_id, [])
            for i in extra:
                if len(invites) >= INBOX_CAP:
                    break
                kind = str(i.get("kind") or "")
                rec = {
                    "kind": kind,
                    "from": str(i.get("from_name") or ""),
                    "from_id": str(i.get("from_id") or ""),
                }
                if kind == "room":
                    rec["code"] = str(i.get("code") or "")
                invites.append(rec)
        return _reply("inbox", name=nick, calls=out, invites=invites)

    def _are_friends(self, a: str, b: str) -> bool:
        return b in self.friendships.get(a, set())

    def _push_invite(self, dest_id: str, item: dict) -> None:
        bucket = self.invites.setdefault(dest_id, [])
        bucket.append(item)
        if len(bucket) > INBOX_CAP:
            self.invites[dest_id] = bucket[-INBOX_CAP:]

    def _id_for_name(self, nick: str) -> str:
        if not nick:
            return ""
        rec = self.presence.get(nick) or {}
        found = _normalize_friend_id(rec.get("friend_id"))
        if found:
            return found
        for fid, item in self.presence_ids.items():
            if str(item.get("name") or "") == nick:
                return _normalize_friend_id(fid)
        return ""

    def _friend_invite(self, parsed: dict) -> bytes:
        src = _normalize_friend_id(parsed.get("from_id"))
        dst = _normalize_friend_id(parsed.get("to_id"))
        to_name = _sanitize_nick(parsed.get("to_name"))
        name = _sanitize_nick(parsed.get("from_name"))
        if not dst and to_name:
            dst = self._id_for_name(to_name)
        if not src or src == dst:
            return _reply("error", reason="id")
        if not dst:
            return _reply("offline", to=to_name)
        if not name:
            name = "Caçador"
        if self._are_friends(src, dst):
            return _reply("already", to=dst, name=to_name)
        bucket = self.friend_pending.setdefault(dst, [])
        for item in bucket:
            if str(item.get("from_id") or "") == src:
                item["ts"] = _now()
                item["from_name"] = name
                return _reply("invited", to=dst, name=to_name)
        bucket.append({"from_id": src, "from_name": name, "ts": _now()})
        if len(bucket) > INBOX_CAP:
            self.friend_pending[dst] = bucket[-INBOX_CAP:]
        return _reply("invited", to=dst, name=to_name)

    def _friend_accept(self, parsed: dict) -> bytes:
        me = _normalize_friend_id(parsed.get("my_id"))
        them = _normalize_friend_id(parsed.get("their_id"))
        my_name = _sanitize_nick(parsed.get("my_name"))
        if not me or not them or me == them:
            return _reply("error", reason="id")
        if not my_name:
            my_name = "Caçador"
        pending = self.friend_pending.get(me, [])
        kept = [p for p in pending if str(p.get("from_id") or "") != them]
        hit = next((p for p in pending if str(p.get("from_id") or "") == them), None)
        if hit is None and not self._are_friends(me, them):
            return _reply("missing", to=them)
        if kept:
            self.friend_pending[me] = kept
        else:
            self.friend_pending.pop(me, None)
        self.friendships.setdefault(me, set()).add(them)
        self.friendships.setdefault(them, set()).add(me)
        their_name = str((hit or {}).get("from_name") or "")
        self._push_invite(them, {
            "kind": "friend_ok",
            "from_id": me,
            "from_name": my_name,
            "ts": _now(),
            "ttl": FRIEND_INVITE_TTL,
        })
        return _reply("accepted", to=them, name=their_name)

    def _friend_decline(self, parsed: dict) -> bytes:
        me = _normalize_friend_id(parsed.get("my_id"))
        them = _normalize_friend_id(parsed.get("their_id"))
        if not me or not them:
            return _reply("error", reason="id")
        pending = self.friend_pending.get(me, [])
        kept = [p for p in pending if str(p.get("from_id") or "") != them]
        if kept:
            self.friend_pending[me] = kept
        else:
            self.friend_pending.pop(me, None)
        return _reply("declined", to=them)

    def _room_invite(self, parsed: dict) -> bytes:
        src = _normalize_friend_id(parsed.get("from_id"))
        dst = _normalize_friend_id(parsed.get("to_id"))
        to_name = _sanitize_nick(parsed.get("to_name"))
        name = _sanitize_nick(parsed.get("from_name"))
        code = _normalize_code(parsed.get("code"))
        if not dst and to_name:
            dst = self._id_for_name(to_name)
        if not src or not dst or src == dst:
            return _reply("error", reason="id")
        if not code:
            return _reply("error", reason="code")
        if not name:
            name = "Caçador"
        target = self.presence_ids.get(dst)
        if target is None:
            return _reply("offline", to=dst)
        self._push_invite(dst, {
            "kind": "room",
            "from_id": src,
            "from_name": name,
            "code": code,
            "ts": _now(),
            "ttl": ROOM_INVITE_TTL,
        })
        return _reply("invited", to=dst, code=code)

    def _friends_status(self, parsed: dict) -> bytes:
        me = _normalize_friend_id(parsed.get("friend_id"))
        if not me:
            return _reply("error", reason="id")
        with_code: list[dict] = []
        online: list[dict] = []
        for them in sorted(self.friendships.get(me, set())):
            rec = self.presence_ids.get(them) or {}
            name = _sanitize_nick(rec.get("name"))
            code = _normalize_code(rec.get("code"))
            if not name:
                for nick, p in self.presence.items():
                    if _normalize_friend_id(p.get("friend_id")) == them:
                        name = nick
                        if not code:
                            code = _normalize_code(p.get("code"))
                        break
            if not name:
                continue
            item = {"name": name, "friend_id": them, "code": code}
            if code:
                with_code.append(item)
            else:
                online.append(item)
        out = with_code + online
        raw = _reply("friends_status", friends=out)
        while not raw and out:
            out.pop()
            raw = _reply("friends_status", friends=out)
        return raw if raw else _reply("friends_status", friends=[])

    def _relay_bind(self, parsed: dict, addr: tuple[str, int]) -> bytes:
        code = _normalize_code(parsed.get("code"))
        if not code:
            return _reply("error", reason="code")
        room = self.rooms.get(code)
        if room is None:
            room = {
                "ip": addr[0],
                "port": 17777,
                "name": "Anfitrião",
                "version_code": 0,
                "ts": _now(),
                "wan_host": None,
                "wan_guests": {},
            }
            self.rooms[code] = room
        prev_host = room.get("wan_host")
        if prev_host is not None and prev_host != addr:
            for gaddr in list((room.get("wan_guests") or {}).values()):
                self.relay_peers.pop(gaddr, None)
            room["wan_guests"] = {}
            if prev_host in self.relay_peers:
                self.relay_peers.pop(prev_host, None)
        room["wan_host"] = addr
        room["ts"] = _now()
        self.relay_peers[addr] = {"code": code, "role": "host", "slot": 0}
        self.relay_host = addr
        return _reply("bound", code=code, relay_port=self.relay_port)

    def _relay_join(self, parsed: dict, addr: tuple[str, int]) -> bytes:
        code = _normalize_code(parsed.get("code"))
        if not code:
            return _reply("error", reason="code")
        room = self.rooms.get(code)
        if room is None:
            return _reply("missing", code=code)
        guests: dict = room.setdefault("wan_guests", {})
        for slot, gaddr in list(guests.items()):
            if gaddr == addr:
                room["ts"] = _now()
                self.relay_peers[addr] = {"code": code, "role": "guest", "slot": int(slot)}
                return _reply("joined", code=code, slot=int(slot))
        if len(guests) >= 3:
            return _reply("full", code=code)
        used = {int(s) for s in guests.keys()}
        slot = 1
        while slot in used:
            slot += 1
        guests[slot] = addr
        room["ts"] = _now()
        self.relay_peers[addr] = {"code": code, "role": "guest", "slot": slot}
        if self.relay_guest is None:
            self.relay_guest = addr
        return _reply("joined", code=code, slot=slot)

    def handle_relay(self, data: bytes, addr: tuple[str, int]) -> None:
        if not data or len(data) > RELAY_MAX:
            return
        if data[:1] == b"{":
            try:
                parsed = json.loads(data.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                return
            if not isinstance(parsed, dict):
                return
            try:
                proto = int(parsed.get("proto") or 0)
            except (TypeError, ValueError):
                return
            if parsed.get("magic") != MAGIC or proto != PROTO:
                return
            op = str(parsed.get("op") or "")
            reply = b""
            if op == "relay_bind":
                reply = self._relay_bind(parsed, addr)
            elif op == "relay_join":
                reply = self._relay_join(parsed, addr)
            if reply:
                try:
                    self.relay.sendto(reply, addr)
                except OSError:
                    pass
            return
        peer = self.relay_peers.get(addr)
        if peer is None:
            self._relay_legacy(data, addr)
            return
        room = self.rooms.get(str(peer.get("code") or ""))
        if room is None:
            return
        role = str(peer.get("role") or "")
        if role == "guest":
            host = room.get("wan_host")
            if host is None:
                return
            slot = int(peer.get("slot") or 1)
            try:
                self.relay.sendto(bytes([slot]) + data, host)
            except OSError:
                pass
            return
        if role == "host":
            if len(data) < 2:
                return
            slot = int(data[0])
            payload = data[1:]
            dest = (room.get("wan_guests") or {}).get(slot)
            if dest is None:
                return
            try:
                self.relay.sendto(payload, dest)
            except OSError:
                pass

    def _relay_legacy(self, data: bytes, addr: tuple[str, int]) -> None:
        if self.relay_host is None:
            return
        host_ip, host_port = self.relay_host
        if addr[0] == host_ip and addr[1] == host_port:
            if self.relay_guest is not None:
                try:
                    self.relay.sendto(data, self.relay_guest)
                except OSError:
                    pass
            return
        if self.relay_guest is None:
            self.relay_guest = addr
        if addr != self.relay_guest:
            return
        try:
            self.relay.sendto(data, (host_ip, host_port))
        except OSError:
            pass

    def _serve_stream(self, listener: socket.socket, kind: str) -> None:
        try:
            conn, addr = listener.accept()
        except OSError:
            return
        try:
            conn.settimeout(1.0)
            chunks: list[bytes] = []
            while True:
                try:
                    part = conn.recv(HTTP_MAX)
                except socket.timeout:
                    break
                if not part:
                    break
                chunks.append(part)
                data = b"".join(chunks)
                if len(data) > HTTP_MAX:
                    break
                if kind == "http" and b"\r\n\r\n" in data:
                    head, _, rest = data.partition(b"\r\n\r\n")
                    need = 0
                    for line in head.split(b"\r\n")[1:]:
                        if line.lower().startswith(b"content-length:"):
                            try:
                                need = int(line.split(b":", 1)[1].strip() or 0)
                            except ValueError:
                                need = 0
                    if len(rest) >= need:
                        break
                if kind == "tcp" and (b"\n" in data or len(data) >= MAX_BYTES):
                    break
            data = b"".join(chunks)
            if kind == "http":
                reply = self.handle_http(data, addr)
            else:
                reply = self.handle_tcp_line(data, addr)
            if reply:
                conn.sendall(reply)
        except OSError:
            pass
        finally:
            try:
                conn.close()
            except OSError:
                pass

    def serve(self) -> None:
        print(
            "Sala da estrela em %s:%d UDP/TCP (HTTP %d, relay %d). Ctrl+C para desligar."
            % (self.bind, self.port, self.http_port, self.relay_port),
            flush=True,
        )
        try:
            while True:
                watch = [self.ctrl, self.relay, self.tcp]
                if self.http is not None:
                    watch.append(self.http)
                ready, _, _ = select.select(watch, [], [], 0.5)
                for sock in ready:
                    if sock is self.ctrl:
                        try:
                            data, addr = sock.recvfrom(REPLY_MAX + 64)
                        except OSError:
                            continue
                        try:
                            reply = self.handle_ctrl(data, addr)
                        except Exception:
                            reply = b""
                        if reply:
                            try:
                                self.ctrl.sendto(reply, addr)
                            except OSError:
                                pass
                    elif sock is self.relay:
                        try:
                            data, addr = sock.recvfrom(RELAY_MAX)
                        except OSError:
                            continue
                        self.handle_relay(data, addr)
                    elif self.http is not None and sock is self.http:
                        self._serve_stream(sock, "http")
                    else:
                        self._serve_stream(sock, "tcp")
        except KeyboardInterrupt:
            print("\nSala da estrela desligada.", flush=True)


def _self_test() -> int:
    """Bloqueadores: proto lixo, relay 1:1, poll sem code. HTTP/TCP no mesmo proto."""
    svc = SalaMeio("127.0.0.1", 0, 0, 0)
    addr = ("127.0.0.1", 9)
    try:
        for proto in ("nope", ["x"], {"a": 1}):
            raw = json.dumps({"magic": MAGIC, "proto": proto, "op": "ping"}).encode("utf-8")
            if svc.handle_ctrl(raw, addr) != b"":
                print("FAIL proto lixo respondeu: %r" % (proto,), file=sys.stderr)
                return 1
        ping = json.dumps({"magic": MAGIC, "proto": PROTO, "op": "ping"}).encode("utf-8")
        if b'"op":"pong"' not in svc.handle_ctrl(ping, addr):
            print("FAIL ping depois do proto lixo", file=sys.stderr)
            return 1

        junk_http = (
            b'POST /sala HTTP/1.1\r\nContent-Length: 54\r\n\r\n'
            b'{"magic":"HASHIRA_MEIO","proto":["x"],"op":"ping"}'
        )
        http_junk = svc.handle_http(junk_http, addr)
        if b'"op":"pong"' in http_junk:
            print("FAIL HTTP proto lixo respondeu pong", file=sys.stderr)
            return 1
        http_ping = svc.handle_http(b"GET /ping HTTP/1.1\r\n\r\n", addr)
        if b'"op":"pong"' not in http_ping:
            print("FAIL HTTP GET /ping", file=sys.stderr)
            return 1
        tcp_junk = svc.handle_tcp_line(
            b'{"magic":"HASHIRA_MEIO","proto":["x"],"op":"ping"}\n', addr
        )
        if tcp_junk:
            print("FAIL TCP proto lixo respondeu", file=sys.stderr)
            return 1
        tcp_ping = svc.handle_tcp_line(ping + b"\n", addr)
        if b'"op":"pong"' not in tcp_ping:
            print("FAIL TCP ping", file=sys.stderr)
            return 1

        sink = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sink.bind(("127.0.0.1", 0))
        host_port = int(sink.getsockname()[1])
        svc._announce({"code": "K7H4MP", "name": "HostSmoke", "port": host_port}, "127.0.0.1")
        host_wan = ("203.0.113.10", 40000)
        g1 = ("192.0.2.10", 50000)
        g2 = ("192.0.2.11", 50001)
        bind_raw = json.dumps(
            {"magic": MAGIC, "proto": PROTO, "op": "relay_bind", "code": "K7H4MP"}
        ).encode("utf-8")
        join_raw = json.dumps(
            {"magic": MAGIC, "proto": PROTO, "op": "relay_join", "code": "K7H4MP"}
        ).encode("utf-8")
        svc.handle_relay(bind_raw, host_wan)
        if svc.rooms["K7H4MP"].get("wan_host") != host_wan:
            print("FAIL relay_bind não gravou wan_host", file=sys.stderr)
            return 1
        svc.handle_relay(join_raw, g1)
        if svc.rooms["K7H4MP"].get("wan_guests", {}).get(1) != g1:
            print("FAIL 1º guest não lockou", file=sys.stderr)
            return 1
        svc.handle_relay(join_raw, g2)
        guests = svc.rooms["K7H4MP"].get("wan_guests") or {}
        if guests.get(1) != g1 or guests.get(2) != g2:
            print("FAIL 2º guest slot=%s" % guests, file=sys.stderr)
            return 1
        class _Sink:
            def __init__(self) -> None:
                self.sent: list[tuple[bytes, tuple]] = []

            def sendto(self, data: bytes, addr: tuple) -> int:
                self.sent.append((data, addr))
                return len(data)

            def close(self) -> None:
                return

        svc.relay = _Sink()  # type: ignore[assignment]
        svc.handle_relay(b"hello", g1)
        if svc.relay.sent != [(b"\x01hello", host_wan)]:
            print("FAIL guest→host slot wrap: %s" % svc.relay.sent, file=sys.stderr)
            return 1
        svc.handle_relay(b"\x01pong", host_wan)
        if svc.relay.sent[-1] != (b"pong", g1):
            print("FAIL host→guest unwrap: %s" % svc.relay.sent, file=sys.stderr)
            return 1
        svc._announce({"code": "K7H4MP", "name": "HostSmoke", "port": host_port}, "127.0.0.1")
        if svc.rooms["K7H4MP"].get("wan_guests", {}).get(1) != g1:
            print("FAIL announce zerou o guest no meio da sala", file=sys.stderr)
            return 1
        sink.close()

        svc._presence({"name": "SobrinhoQA"}, "127.0.0.1")
        svc._call({"from": "HostSmoke", "to": "SobrinhoQA"})
        inbox_raw = svc._poll({"name": "SobrinhoQA"})
        inbox = json.loads(inbox_raw.decode("utf-8"))
        if inbox.get("op") != "inbox":
            print("FAIL poll op=%s" % inbox.get("op"), file=sys.stderr)
            return 1
        calls = inbox.get("calls") or []
        if not calls or str(calls[0].get("from") or "") != "HostSmoke":
            print("FAIL inbox=%s" % calls, file=sys.stderr)
            return 1
        if any("code" in c for c in calls):
            print("FAIL poll devolveu code da sala em calls", file=sys.stderr)
            return 1

        host_id = "ABCD2345"
        kid_id = "EFGH6789"
        inv = json.loads(svc._friend_invite({
            "from_id": host_id, "from_name": "HostSmoke", "to_id": kid_id,
        }).decode("utf-8"))
        if inv.get("op") != "invited":
            print("FAIL friend_invite=%s" % inv, file=sys.stderr)
            return 1
        pend = json.loads(svc._poll({"name": "SobrinhoQA", "friend_id": kid_id}).decode("utf-8"))
        kinds = [str(i.get("kind")) for i in (pend.get("invites") or [])]
        if "friend" not in kinds:
            print("FAIL inbox sem convite de amigo: %s" % pend, file=sys.stderr)
            return 1
        acc = json.loads(svc._friend_accept({
            "my_id": kid_id, "my_name": "SobrinhoQA", "their_id": host_id,
        }).decode("utf-8"))
        if acc.get("op") != "accepted":
            print("FAIL friend_accept=%s" % acc, file=sys.stderr)
            return 1
        ok = json.loads(svc._poll({"name": "HostSmoke", "friend_id": host_id}).decode("utf-8"))
        ok_kinds = [str(i.get("kind")) for i in (ok.get("invites") or [])]
        if "friend_ok" not in ok_kinds:
            print("FAIL quem convidou não viu aceite: %s" % ok, file=sys.stderr)
            return 1
        svc._presence({"name": "Muichiro", "friend_id": "JKLM2345"}, "127.0.0.1")
        by_name = json.loads(svc._friend_invite({
            "from_id": host_id, "from_name": "HostSmoke", "to_name": "Muichiro",
        }).decode("utf-8"))
        if by_name.get("op") != "invited" or by_name.get("to") != "JKLM2345":
            print("FAIL friend_invite por nome=%s" % by_name, file=sys.stderr)
            return 1
        ghost_name = json.loads(svc._friend_invite({
            "from_id": host_id, "from_name": "HostSmoke", "to_name": "Ninguem",
        }).decode("utf-8"))
        if ghost_name.get("op") != "offline":
            print("FAIL friend_invite nome offline=%s" % ghost_name, file=sys.stderr)
            return 1
        svc._presence({"name": "SobrinhoQA", "friend_id": kid_id}, "127.0.0.1")
        room_inv = json.loads(svc._room_invite({
            "from_id": host_id, "from_name": "HostSmoke", "to_id": kid_id, "code": "K7H4MP",
        }).decode("utf-8"))
        if room_inv.get("op") != "invited":
            print("FAIL room_invite=%s" % room_inv, file=sys.stderr)
            return 1
        room_box = json.loads(svc._poll({"name": "SobrinhoQA", "friend_id": kid_id}).decode("utf-8"))
        room_items = [i for i in (room_box.get("invites") or []) if str(i.get("kind")) == "room"]
        if not room_items or str(room_items[0].get("code") or "") != "K7H4MP":
            print("FAIL room invite sem code: %s" % room_box, file=sys.stderr)
            return 1
        ghost = json.loads(svc._room_invite({
            "from_id": host_id, "from_name": "HostSmoke", "to_id": "ZZZZ2222", "code": "K7H4MP",
        }).decode("utf-8"))
        if ghost.get("op") != "offline":
            print("FAIL room_invite offline=%s" % ghost, file=sys.stderr)
            return 1
        svc._presence({"name": "HostSmoke", "friend_id": host_id, "code": "K7H4MP"}, "127.0.0.1")
        st = json.loads(svc._friends_status({"friend_id": kid_id}).decode("utf-8"))
        if st.get("op") != "friends_status":
            print("FAIL friends_status op=%s" % st, file=sys.stderr)
            return 1
        found = [f for f in (st.get("friends") or []) if str(f.get("friend_id")) == host_id]
        if not found or str(found[0].get("code") or "") != "K7H4MP":
            print("FAIL friends_status sem sala do amigo: %s" % st, file=sys.stderr)
            return 1
        bad_id = json.loads(svc._friends_status({}).decode("utf-8"))
        if bad_id.get("op") != "error":
            print("FAIL friends_status sem id=%s" % bad_id, file=sys.stderr)
            return 1
        empty = json.loads(svc._friends_status({"friend_id": "ZZZZ2222"}).decode("utf-8"))
        if empty.get("op") != "friends_status" or (empty.get("friends") or []) != []:
            print("FAIL friends_status vazio=%s" % empty, file=sys.stderr)
            return 1
        long_nick = "A" * 24
        svc._presence({"name": long_nick, "friend_id": "NNNN2222"}, "127.0.0.1")
        if long_nick not in svc.presence:
            print("FAIL NICK_MAX 24 não gravou", file=sys.stderr)
            return 1
        print("sala_meio self-test PASS", flush=True)
        return 0
    finally:
        svc.close()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Sala da estrela — achar código 6 (UDP/TCP/HTTP) e carregar o ENet se precisar."
    )
    parser.add_argument("--bind", default="0.0.0.0", help="Endereço de escuta (default 0.0.0.0)")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Porta UDP/TCP do pedido (default 17779)")
    parser.add_argument("--relay-port", type=int, default=0, help="Porta do ENet (default porta+1)")
    parser.add_argument("--http-port", type=int, default=DEFAULT_HTTP_PORT, help="Porta HTTP (default 8080)")
    parser.add_argument("--self-test", action="store_true", help="Checa proto lixo, relay 1:1 e poll sem code")
    args = parser.parse_args(argv)
    if args.self_test:
        return _self_test()
    if args.port < 1 or args.port > 65535:
        print("porta inválida", file=sys.stderr)
        return 2
    if args.http_port < 1 or args.http_port > 65535 or args.http_port == args.port:
        print("http-port inválida", file=sys.stderr)
        return 2
    relay_port = args.relay_port if args.relay_port > 0 else args.port + 1
    if relay_port < 1 or relay_port > 65535 or relay_port == args.port:
        print("relay-port inválida", file=sys.stderr)
        return 2
    svc = SalaMeio(args.bind, args.port, relay_port, args.http_port)
    try:
        svc.serve()
    finally:
        svc.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
