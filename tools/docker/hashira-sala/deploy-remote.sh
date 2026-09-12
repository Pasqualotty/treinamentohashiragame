#!/bin/sh
set -eu
docker ps --format '{{.Names}}' | sort > /tmp/hashira-before-ps.txt
cd /opt/hashira-sala
docker compose -f tools/docker/hashira-sala/docker-compose.yml up -d --build
docker ps --format '{{.Names}}' | sort > /tmp/hashira-after-ps.txt
echo "---AFTER---"
cat /tmp/hashira-after-ps.txt
echo "---DIFF---"
comm -3 /tmp/hashira-before-ps.txt /tmp/hashira-after-ps.txt
echo "---HEALTH---"
python3 - <<'PY'
import socket
s = socket.create_connection(("127.0.0.1", 8080), 3)
s.sendall(b"GET /ping HTTP/1.1\r\nHost: x\r\n\r\n")
r = s.recv(256)
s.close()
print(r)
raise SystemExit(0 if b"pong" in r else 1)
PY
