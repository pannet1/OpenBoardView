#!/usr/bin/env bash
set -euo pipefail
# Build OpenBoardView for WebAssembly (Emscripten)
#
# Prerequisites:
#   - Emscripten SDK (emcmake, emmake) installed and in PATH
#   - /tmp/emscripten_config: writable Emscripten config with FROZEN_CACHE=False
#     (copy from /usr/share/emscripten/.emscripten and set FROZEN_CACHE = False)
#
# Usage: ./scripts/build-wasm.sh [--debug] [--recompile]

DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$DIR/build_wasm"
BUILD_TYPE="${BUILD_TYPE:-Release}"
RECOMPILE=false
THREADS="${THREADS:-$(nproc 2>/dev/null || echo 4)}"

for arg in "$@"; do
  case $arg in
    --debug) BUILD_TYPE="Debug" ;;
    --recompile) RECOMPILE=true ;;
    *) echo "Unknown: $arg"; exit 1 ;;
  esac
done

if [ "$RECOMPILE" = true ]; then
  echo "rm -rf $BUILD_DIR"
  rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"

echo "==> CMake (WASM, $BUILD_TYPE)"
EM_CONFIG=/tmp/emscripten_config emcmake cmake -S "$DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE"

echo "==> Make ($THREADS threads)"
EM_CONFIG=/tmp/emscripten_config emmake make -C "$BUILD_DIR" -j"$THREADS"

echo ""
echo "Output:"
ls -lh "$BUILD_DIR/src/openboardview/openboardview."{js,wasm}
