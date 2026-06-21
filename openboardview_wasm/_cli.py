import argparse, os, sys
from . import VERSION
from ._app import DEFAULT_WASM_DIR


def main():
    p = argparse.ArgumentParser(description="OpenBoardView WASM test server")
    p.add_argument("port", nargs="?", type=int, default=8080,
                   help="port to listen on (default: 8080)")
    p.add_argument("--host", default="0.0.0.0",
                   help="bind address (default: 0.0.0.0)")
    p.add_argument("--static-dir", default=None,
                   help="path to openboardview.js (default: package _static/)")
    p.add_argument("--version", action="version", version=VERSION)
    args = p.parse_args()

    static_dir = args.static_dir or str(DEFAULT_WASM_DIR)

    if not os.path.isfile(os.path.join(static_dir, "openboardview.js")):
        print(f"Error: openboardview.js not found in {static_dir}")
        print("Run ./scripts/build-wasm.sh first, or pass --static-dir")
        sys.exit(1)

    try:
        import uvicorn
    except ImportError:
        import http.server, socketserver

        os.chdir(static_dir)

        class H(http.server.SimpleHTTPRequestHandler):
            def end_headers(self):
                self.send_header("Cross-Origin-Opener-Policy", "same-origin")
                self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
                self.send_header("Access-Control-Allow-Origin", "*")
                super().end_headers()
            def log_message(self, *a): pass

        with socketserver.TCPServer(("0.0.0.0", args.port), H) as httpd:
            print(f"Serving OpenBoardView WASM at http://localhost:{args.port}")
            httpd.serve_forever()
    else:
        from ._app import make_static_files_app
        app = make_static_files_app(static_dir)
        print(f"Serving OpenBoardView WASM at http://localhost:{args.port}")
        uvicorn.run(app, host=args.host, port=args.port, log_level="warning")
