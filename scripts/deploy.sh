#!/usr/bin/env bash
set -euo pipefail
# Deploy asm.js build output to a target directory (e.g., FastAPI static folder)
#
# Usage: ./scripts/deploy.sh [target-dir]
#   target-dir defaults to ../ecomsense-schematics/static/wasm/

DIR="$(cd "$(dirname "$0")/.." && pwd)"
WASM_DIR="$DIR/build_wasm/src/openboardview"
TARGET="${1:-$DIR/../ecomsense-schematics/static/wasm}"

if [ ! -f "$WASM_DIR/openboardview.js" ]; then
  echo "No build found at $WASM_DIR"
  echo "Run ./scripts/build-wasm.sh first"
  exit 1
fi

mkdir -p "$TARGET"

echo "Deploying to: $TARGET"
cp -v "$WASM_DIR/openboardview.js" "$TARGET/"
if [ -f "$WASM_DIR/index.html" ]; then
  cp -v "$WASM_DIR/index.html" "$TARGET/"
fi

echo ""
echo "Deployed files:"
ls -lh "$TARGET"/openboardview.* "$TARGET"/index.html 2>/dev/null

echo ""
echo "=== FastAPI Integration ==="
echo "1. Mount as static files in your FastAPI app:"
echo ""
echo "   from fastapi.staticfiles import StaticFiles"
echo "   app.mount(\"/wasm\", StaticFiles(directory=\"static/wasm\"), name=\"wasm\")"
echo ""
echo "2. Add COOP/COEP headers via middleware:"
echo ""
echo "   @app.middleware(\"http\")"
echo "   async def add_coop_coep(request, call_next):"
echo "     response = await call_next(request)"
echo "     response.headers[\"Cross-Origin-Opener-Policy\"] = \"same-origin\""
echo "     response.headers[\"Cross-Origin-Embedder-Policy\"] = \"require-corp\""
echo "     return response"
echo ""
echo "3. Use from your SPA:"
echo ""
echo "   const Module = await new Promise((resolve) => {"
echo "     const m = { onRuntimeInitialized: () => resolve(m) };"
echo "     const s = document.createElement('script');"
echo "     s.src = '/wasm/openboardview.js';"
echo "     document.head.appendChild(s);"
echo "   });"
echo ""
echo "   // Load a board file"
echo "   fetch('https://server/path/board.brd')"
echo "     .then(r => r.arrayBuffer())"
echo "     .then(buf => Module.loadBoardFromMemory(buf));"
echo ""
echo "4. Or via URL parameter in the test HTML:"
echo "   http://yourdomain/wasm/?file=https://server/path/board.brd"
