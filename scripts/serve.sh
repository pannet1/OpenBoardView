#!/usr/bin/env bash
set -euo pipefail
# Start local HTTP server for testing the WASM build
#
# Usage: ./scripts/serve.sh [port]

DIR="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-8080}"
WASM_DIR="$DIR/build_wasm/src/openboardview"

if [ ! -f "$WASM_DIR/openboardview.js" ]; then
  echo "No build found at $WASM_DIR"
  echo "Run ./scripts/build-wasm.sh first"
  exit 1
fi

echo "Serving OpenBoardView at http://localhost:$PORT"
echo "Files: $(ls "$WASM_DIR"/openboardview.* 2>/dev/null)"

# Prefer python3 test server (has COOP/COEP headers built in)
if command -v python3 &>/dev/null; then
  exec python3 "$DIR/test_server.py" "$PORT"
fi

# Fallback: compile and run C++ server
echo "python3 not found, compiling wasm_server..."
c++ -std=c++11 -o /tmp/wasm_server "$DIR/cmake/wasm_server.cpp"
exec /tmp/wasm_server "$PORT" "$WASM_DIR"
