#!/usr/bin/env python3
"""
notes.nvim graph server — stdlib only, no pip required.
Serves the graph UI and proxies open-in-neovim requests.
"""
import argparse
import json
import os
import subprocess
import urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

parser = argparse.ArgumentParser()
parser.add_argument("--socket", required=True,  help="Neovim socket path (vim.v.servername)")
parser.add_argument("--vault",  required=True,  help="Vault root path")
parser.add_argument("--port",   type=int, default=7842)
parser.add_argument("--html",   required=True,  help="Path to graph.html")
ARGS = parser.parse_args()

GRAPH_JSON     = os.path.join(ARGS.vault, ".notes-graph.json")
POSITIONS_JSON = os.path.join(ARGS.vault, ".notes-graph-positions.json")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # silence request logs

    # ── helpers ──────────────────────────────────────────────────────────────

    def _send(self, code, ctype, body: bytes):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, data):
        self._send(200, "application/json", json.dumps(data).encode())

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0))
        return self.rfile.read(length)

    # ── GET ──────────────────────────────────────────────────────────────────

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        qs     = urllib.parse.parse_qs(parsed.query)
        path   = parsed.path

        if path == "/":
            with open(ARGS.html, "rb") as f:
                self._send(200, "text/html; charset=utf-8", f.read())

        elif path == "/graph.json":
            try:
                with open(GRAPH_JSON, "rb") as f:
                    self._send(200, "application/json", f.read())
            except FileNotFoundError:
                self._send(404, "text/plain", b"graph.json not found")

        elif path == "/positions.json":
            try:
                with open(POSITIONS_JSON, "rb") as f:
                    self._send(200, "application/json", f.read())
            except FileNotFoundError:
                self._send(200, "application/json", b"{}")

        elif path == "/note":
            note_path = qs.get("p", [None])[0]
            if note_path and os.path.isfile(note_path):
                with open(note_path, "r", encoding="utf-8") as f:
                    self._send(200, "text/plain; charset=utf-8", f.read().encode())
            else:
                self._send(404, "text/plain", b"not found")

        elif path == "/open":
            note_path = qs.get("p", [None])[0]
            if note_path:
                subprocess.Popen([
                    "nvim", "--server", ARGS.socket,
                    "--remote-silent", note_path,
                ])
                self._json({"ok": True})
            else:
                self._send(400, "text/plain", b"missing ?p=")

        else:
            self._send(404, "text/plain", b"not found")

    # ── POST ─────────────────────────────────────────────────────────────────

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)

        if parsed.path == "/positions":
            try:
                data = json.loads(self._read_body())
                with open(POSITIONS_JSON, "w", encoding="utf-8") as f:
                    json.dump(data, f)
                self._json({"ok": True})
            except Exception as e:
                self._send(400, "text/plain", str(e).encode())
        else:
            self._send(404, "text/plain", b"not found")


if __name__ == "__main__":
    addr = ("127.0.0.1", ARGS.port)
    httpd = HTTPServer(addr, Handler)
    print(f"notes graph server → http://localhost:{ARGS.port}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
