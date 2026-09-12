#!/usr/bin/env python3
import socket
import sys

host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
port = int(sys.argv[2]) if len(sys.argv) > 2 else 8080
s = socket.create_connection((host, port), 3)
s.sendall(b"GET /ping HTTP/1.1\r\nHost: x\r\n\r\n")
r = s.recv(512)
s.close()
print(r)
raise SystemExit(0 if b"pong" in r else 1)
