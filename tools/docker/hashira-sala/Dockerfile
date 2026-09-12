FROM python:3.12-slim

WORKDIR /app
COPY tools/sala_meio.py /app/sala_meio.py

EXPOSE 17779/udp
EXPOSE 17779/tcp
EXPOSE 17780/udp
EXPOSE 8080/tcp

HEALTHCHECK --interval=20s --timeout=3s --retries=3 CMD python -c "import socket; s=socket.create_connection(('127.0.0.1',8080),2); s.sendall(b'GET /ping HTTP/1.1\r\nHost: x\r\n\r\n'); r=s.recv(256); s.close(); raise SystemExit(0 if b'pong' in r else 1)"

CMD ["python", "-u", "/app/sala_meio.py", "--bind", "0.0.0.0", "--port", "17779", "--http-port", "8080"]
