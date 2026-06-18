#!/usr/bin/env python3
"""Simple HTTP server for testing OpenBoardView WASM build."""

import http.server
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
WASM_DIR = os.path.join(os.path.dirname(__file__), "build_wasm", "src", "openboardview")


class WASMHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WASM_DIR, **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


if __name__ == "__main__":
    os.chdir(WASM_DIR)
    print(f"Serving OpenBoardView WASM at http://localhost:{PORT}")
    print(f"Files: {os.listdir('.')}")
    http.server.HTTPServer(("", PORT), WASMHandler).serve_forever()
