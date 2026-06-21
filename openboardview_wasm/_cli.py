import argparse, os, sys
from . import VERSION
from ._app import DEFAULT_WASM_DIR


def cmd_fetch(args):
    from ._fetch import fetch
    fetch(target_dir=args.dir)


def cmd_serve(args):
    static_dir = args.dir or str(DEFAULT_WASM_DIR)
    if not os.path.isfile(os.path.join(static_dir, "openboardview.js")):
        print(f"Error: openboardview.js not found in {static_dir}")
        print("Run 'openboardview-wasm fetch' or pass --dir")
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
            print(f"Serving OpenBoardView at http://localhost:{args.port}")
            httpd.serve_forever()
    else:
        from ._app import make_static_files_app
        app = make_static_files_app(static_dir)
        print(f"Serving OpenBoardView at http://localhost:{args.port}")
        uvicorn.run(app, host=args.host, port=args.port, log_level="warning")


def cmd_build(args):
    import subprocess
    repo_root = os.path.join(os.path.dirname(__file__), "..", "..")
    script = os.path.join(repo_root, "scripts", "build-wasm.sh")
    if not os.path.isfile(script):
        print("Error: build-wasm.sh not found. This command requires the full C++ repo.")
        sys.exit(1)
    subprocess.check_call(["bash", script], cwd=repo_root)


def main():
    p = argparse.ArgumentParser(description="OpenBoardView WASM tools")
    p.add_argument("--version", action="version", version=VERSION)
    subs = p.add_subparsers(dest="command", required=True)

    # fetch
    pf = subs.add_parser("fetch", help="download pre-built JS from GitHub")
    pf.add_argument("--dir", default="wasm", help="target directory (default: wasm/)")
    pf.set_defaults(func=cmd_fetch)

    # serve
    ps = subs.add_parser("serve", help="start dev server")
    ps.add_argument("port", nargs="?", type=int, default=8080)
    ps.add_argument("--host", default="0.0.0.0")
    ps.add_argument("--dir", default=None, help="path to openboardview.js")
    ps.set_defaults(func=cmd_serve)

    # build
    pb = subs.add_parser("build", help="build from C++ source (needs Emscripten)")
    pb.set_defaults(func=cmd_build)

    args = p.parse_args()
    args.func(args)
