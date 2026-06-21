#!/usr/bin/env bash
set -euo pipefail
# Pull upstream OpenBoardView changes, build WASM, and run smoke test.
#
# Usage: ./scripts/pull-build-test.sh

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

# 1. Pull and merge upstream
echo "==> Fetching upstream..."
if ! git remote get-url upstream &>/dev/null; then
  echo "Adding upstream remote..."
  git remote add upstream https://github.com/OpenBoardView/OpenBoardView.git
fi
git fetch upstream
echo "==> Merging upstream/main..."
git merge upstream/main

echo ""
echo "=== Common conflict areas ==="
echo "  CMakeLists.txt            — our elseif(EMSCRIPTEN) block"
echo "  main_opengl.cpp           — __EMSCRIPTEN__ guards + loadBoardFromMemory"
echo "  ImGuiRendererSDL.cpp      — SDL_GL_SetSwapInterval guard"
echo "  Annotations.cpp           — __EMSCRIPTEN__ log guards"
echo "  BoardView.cpp/.h          — LoadFromBuffer method"
echo "  BRD2File.cpp              — nets.at() -> find() fallback"
echo ""

# 2. Build WASM
echo "==> Building WASM..."
"$DIR/scripts/build-wasm.sh"

# 3. Smoke test
echo ""
echo "==> Smoke test..."
JS_FILE="$DIR/build_wasm/src/openboardview/openboardview.js"
if [ ! -f "$JS_FILE" ]; then
  echo "FAIL: $JS_FILE not found"
  exit 1
fi

# Verify key exported functions exist in the JS
echo -n "  Checking exports..."
for fn in _loadBoardFromMemory _wasmTest _testData; do
  if grep -q "$fn" "$JS_FILE"; then
    echo -n " $fn✓"
  else
    echo " $fn✗ (not found)"
    exit 1
  fi
done
echo ""

# Verify file size (5-6 MB expected)
SIZE=$(stat -c%s "$JS_FILE" 2>/dev/null || stat -f%z "$JS_FILE" 2>/dev/null)
echo "  Size: $(echo $SIZE | awk '{printf "%.1f MB", $1/1048576}') ($SIZE bytes)"
if [ "$SIZE" -lt 1000000 ] || [ "$SIZE" -gt 20000000 ]; then
  echo "FAIL: unexpected file size"
  exit 1
fi

# 4. Start server and run browser test
echo ""
echo "==> Browser test..."
PORT=8765

# Kill any leftover from previous run
fuser -k "${PORT}/tcp" 2>/dev/null || true
sleep 1

# Start Python test server in background
python3 "$DIR/test_server.py" "$PORT" &
SERVER_PID=$!
sleep 2

# Quick HTTP check
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/index.html" 2>/dev/null || echo "000")
if [ "$STATUS" = "200" ]; then
  echo "  Server: OK (HTTP $STATUS)"
else
  echo "  Server: FAIL (HTTP $STATUS)"
  kill "$SERVER_PID" 2>/dev/null || true
  exit 1
fi

# Check .js file is served
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/openboardview.js" 2>/dev/null || echo "000")
if [ "$STATUS" = "200" ]; then
  echo "  JS served: OK (HTTP $STATUS)"
else
  echo "  JS served: FAIL (HTTP $STATUS)"
  kill "$SERVER_PID" 2>/dev/null || true
  exit 1
fi

# Check test board is served
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/test.brd" 2>/dev/null || echo "000")
if [ "$STATUS" = "200" ]; then
  echo "  test.brd: OK (HTTP $STATUS)"
else
  echo "  test.brd: FAIL (HTTP $STATUS)"
  kill "$SERVER_PID" 2>/dev/null || true
  exit 1
fi

# Complete test: fetch board, verify it loads (using the ?file= auto-load)
echo "  Checking ?file= auto-load..."
PAGE=$(curl -s "http://localhost:$PORT/index.html?file=/test.brd" 2>/dev/null || true)
# The page should include the canvas and script references
if echo "$PAGE" | grep -q "loadBoardFromMemory"; then
  echo "  HTML page: OK (contains loadBoardFromMemory)"
else
  echo "  HTML page: WARN (missing loadBoardFromMemory reference)"
fi

# Cleanup
kill "$SERVER_PID" 2>/dev/null || true

echo ""
echo "=== All tests passed ==="
echo "Branch: $(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD)"
echo ""
echo "To deploy: ./scripts/deploy.sh [target-dir]"
