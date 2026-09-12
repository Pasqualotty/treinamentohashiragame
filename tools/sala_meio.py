#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Sala da estrela — celulares se acham sem ligar PC.

UDP (17779) + TCP (17779) + HTTP (8080) + relay ENet (17780).
O APK já aponta pra cá. PC local é só reserva de dev.

Sem Firebase, sem Play Games, sem conta.
Sala caiu: o jogo ainda abre; Criar/Entrar avisa em português.

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
HTTP_MAX = 4096
ROOM_TTL = 90.0
PRESENCE_TTL = 35.0
CALL_TTL = 45.0
CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
NICK_MAX = 14


def _now() -> float:
    return time.monotonic()


def _normalize_code(raw: object) -> str:
    s = str(raw or "").strip().replace(" ", "").upper()
    if len(s) != 6:
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
    if len(raw) > MAX_BYTES:
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
        self.calls: dict[str, list[dict]] = {}
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
        for nick, items in list(self.calls.items()):
            kept = [c for c in items if t - float(c["ts"]) <= CALL_TTL]
            if kept:
                self.calls[nick] = kept
            else:
                self.calls.pop(nick, None)

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
        self.rooms[code] = {
            "ip": src_ip,
            "port": enet_port,
            "name": nick,
            "version_code": version_code,
            "ts": _now(),
        }
        self.presence[nick] = {"ts": _now(), "code": code, "ip": src_ip}
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
        prev = self.presence.get(nick, {})
        self.presence[nick] = {
            "ts": _now(),
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
        items = self.calls.pop(nick, [])
        out = [{"from": str(i.get("from") or "")} for i in items]
        return _reply("inbox", name=nick, calls=out)

    def handle_relay(self, data: bytes, addr: tuple[str, int]) -> None:
        if not data or self.relay_host is None:
            return
        host_ip, host_port = self.relay_host
        if addr[0] == host_ip and addr[1] == host_port:
            if self.relay_guest is not None:
                self.relay.sendto(data, self.relay_guest)
            return
        if self.relay_guest is None:
            self.relay_guest = addr
        if addr != self.relay_guest:
            return
        self.relay.sendto(data, (host_ip, host_port))

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
                            data, addr = sock.recvfrom(MAX_BYTES + 64)
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
                            data, addr = sock.recvfrom(MAX_BYTES + 64)
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
        g1 = ("192.0.2.10", 50000)
        g2 = ("192.0.2.11", 50001)
        svc.handle_relay(b"g1", g1)
        if svc.relay_guest != g1:
            print("FAIL 1º guest não lockou", file=sys.stderr)
            return 1
        svc.handle_relay(b"g2", g2)
        if svc.relay_guest != g1:
            print("FAIL 2º peer roubou o relay", file=sys.stderr)
            return 1
        svc._announce({"code": "K7H4MP", "name": "HostSmoke", "port": host_port}, "127.0.0.1")
        if svc.relay_guest != g1:
            print("FAIL announce zerou o guest no meio da partida", file=sys.stderr)
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
        if any("code" in c for c in calls) or b'"code"' in inbox_raw:
            print("FAIL poll devolveu code da sala", file=sys.stderr)
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
