"""Local Flutter web proxy: 127.0.0.1:8002 -> SSH tunnel 127.0.0.1:8001.

Run from the Flutter project with: python3 tool/local_api_proxy.py
"""

import http.client
import json
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


LOCAL_ORIGIN = re.compile(r"http://(?:localhost|127\.0\.0\.1)(?::\d+)?")
METHODS = "GET, HEAD, POST, PUT, PATCH, DELETE"
HEADERS = "Accept, Content-Type, Authorization"

BACKEND_PORT = 8000
PROXY_PORT = 8001
LOCALHOST = "127.0.0.1"

class ApiProxyHandler(BaseHTTPRequestHandler):
    def _send(self, status, body=b"", content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Vary", "Origin")
        origin = self.headers.get("Origin", "")
        if LOCAL_ORIGIN.fullmatch(origin):
            self.send_header("Access-Control-Allow-Origin", origin)
            self.send_header("Access-Control-Allow-Methods", METHODS)
            self.send_header("Access-Control-Allow-Headers", HEADERS)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _error(self, status, message):
        self._send(status, json.dumps({"detail": message}).encode())

    def _allowed(self):
        origin = self.headers.get("Origin")
        if origin is not None and not LOCAL_ORIGIN.fullmatch(origin):
            self._error(403, "Only local Flutter web origins are allowed")
            return False
        target = urlsplit(self.path)
        if target.scheme or target.netloc or not target.path.startswith("/api/v1/"):
            self._error(404, "This proxy only forwards /api/v1/ requests")
            return False
        return True

    def do_OPTIONS(self):
        if not self._allowed():
            return
        method = self.headers.get("Access-Control-Request-Method", "GET")
        if method not in METHODS.split(", "):
            self._error(405, "Request method is not supported")
            return
        self._send(204)

    def _forward(self):
        if not self._allowed():
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self._error(400, "Invalid Content-Length")
            return
        if not 0 <= length <= 1024 * 1024:
            self._error(413, "Request body is too large")
            return
        body = self.rfile.read(length) if length else None
        headers = {name: self.headers[name] for name in HEADERS.split(", ")
                   if name in self.headers}
        connection = http.client.HTTPConnection(LOCALHOST, BACKEND_PORT, timeout=20)
        try:
            connection.request(self.command, self.path, body=body, headers=headers)
            response = connection.getresponse()
            payload = response.read()
            content_type = response.getheader("Content-Type", "application/json")
        except (OSError, http.client.HTTPException):
            self._error(502, "Cannot reach the backend. Check the SSH tunnel on port 8001.")
            return
        finally:
            connection.close()
        self._send(response.status, payload, content_type)

    do_GET = _forward
    do_HEAD = _forward
    do_POST = _forward
    do_PUT = _forward
    do_PATCH = _forward
    do_DELETE = _forward


if __name__ == "__main__":
    server = ThreadingHTTPServer((LOCALHOST, PROXY_PORT), ApiProxyHandler)
    print(f"Local API proxy: http://{LOCALHOST}:{PROXY_PORT} -> SSH tunnel on port {BACKEND_PORT}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
