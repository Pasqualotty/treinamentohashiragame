#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Computador da sala (saída 3a).

Serviço fino no PC do Matheus: código de 6 → caminho do host.
Se o Wi-Fi da casa não achar, o mesmo PC pode carregar o ENet (relay UDP).

Sem Firebase, sem Play Games, sem Hostinger, sem conta.
Desligou o PC: o jogo ainda abre; a sala avisa em português.

Uso:
  python tools/sala_meio.py
  python tools/sala_meio.py --port 17779 --bind 0.0.0.0
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
MAX_BYTES = 512
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


class SalaMeio:
    def __init__(self, bind: str, port: int, relay_port: int) -> None:
        self.bind = bind
        self.port = port
        self.relay_port = relay_port
        self.ctrl = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.ctrl.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.ctrl.bind((bind, port))
        self.relay = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.relay.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.relay.bind((bind, relay_port))
        self.rooms: dict[str, dict] = {}
        self.presence: dict[str, dict] = {}
        self.calls: dict[str, list[dict]] = {}
        self.relay_host: tuple[str, int] | None = None
        self.relay_guest: tuple[str, int] | None = None

    def close(self) -> None:
        self.ctrl.close()
        self.relay.close()

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
        if parsed.get("magic") != MAGIC or int(parsed.get("proto") or 0) != PROTO:
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
        self.relay_host = (src_ip, enet_port)
        self.relay_guest = None
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
        out = [{"from": str(i.get("from") or ""), "code": str(i.get("code") or "")} for i in items]
        return _reply("inbox", name=nick, calls=out)

    def handle_relay(self, data: bytes, addr: tuple[str, int]) -> None:
        if not data or self.relay_host is None:
            return
        host_ip, host_port = self.relay_host
        if addr[0] == host_ip and addr[1] == host_port:
            if self.relay_guest is not None:
                self.relay.sendto(data, self.relay_guest)
            return
        self.relay_guest = addr
        self.relay.sendto(data, (host_ip, host_port))

    def serve(self) -> None:
        print(
            "Computador da sala ligado em %s:%d (relay %d). Ctrl+C para desligar."
            % (self.bind, self.port, self.relay_port),
            flush=True,
        )
        try:
            while True:
                ready, _, _ = select.select([self.ctrl, self.relay], [], [], 0.5)
                for sock in ready:
                    try:
                        data, addr = sock.recvfrom(MAX_BYTES + 64)
                    except OSError:
                        continue
                    if sock is self.ctrl:
                        reply = self.handle_ctrl(data, addr)
                        if reply:
                            try:
                                self.ctrl.sendto(reply, addr)
                            except OSError:
                                pass
                    else:
                        self.handle_relay(data, addr)
        except KeyboardInterrupt:
            print("\nComputador da sala desligado.", flush=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Computador da sala — achar código 6 e carregar o ENet se precisar.")
    parser.add_argument("--bind", default="0.0.0.0", help="Endereço de escuta (default 0.0.0.0)")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Porta do pedido (default 17779)")
    parser.add_argument("--relay-port", type=int, default=0, help="Porta do ENet no PC (default porta+1)")
    args = parser.parse_args(argv)
    if args.port < 1 or args.port > 65535:
        print("porta inválida", file=sys.stderr)
        return 2
    relay_port = args.relay_port if args.relay_port > 0 else args.port + 1
    if relay_port < 1 or relay_port > 65535 or relay_port == args.port:
        print("relay-port inválida", file=sys.stderr)
        return 2
    svc = SalaMeio(args.bind, args.port, relay_port)
    try:
        svc.serve()
    finally:
        svc.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
