#!/usr/bin/env bash
set -euo pipefail
# Merge upstream OpenBoardView commits and verify both native + WASM builds
#
# When OpenBoardView upstream releases new changes, this script:
#   1. Fetches upstream/main
#   2. Merges into your current branch
#   3. Builds native to catch C++ breakage
#   4. Builds WASM to catch Emscripten-specific breakage
#
# This lets you detect integration issues early before they pile up.
#
# Prerequisites:
#   - Upstream remote added: git remote add upstream https://github.com/OpenBoardView/OpenBoardView.git
#   - Emscripten SDK available for WASM build
#
# Usage: ./scripts/merge-upstream.sh

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

# Check for upstream remote
if ! git remote get-url upstream &>/dev/null; then
  echo "Adding upstream remote..."
  git remote add upstream https://github.com/OpenBoardView/OpenBoardView.git
fi

echo "==> Fetching upstream..."
git fetch upstream

echo "==> Merging upstream/main..."
git merge upstream/main

echo ""
echo "=== Common conflict areas ==="
echo "  CMakeLists.txt       — our elseif(EMSCRIPTEN) GL/PkgConfig block"
echo "  main_opengl.cpp      — our __EMSCRIPTEN__ guard on while(!done)"
echo "  ImGuiRendererSDL.cpp — our SDL_GL_SetSwapInterval guard"
echo "  BoardView.cpp        — LoadFromBuffer is a new method, should merge clean"
echo ""

echo "=== Verify native build ==="
NATIVE_DIR="$DIR/build_native"
mkdir -p "$NATIVE_DIR"
cmake -S "$DIR" -B "$NATIVE_DIR" -DCMAKE_BUILD_TYPE=Release 2>&1 | tail -5
cmake --build "$NATIVE_DIR" -j"$(nproc)" 2>&1 | tail -10
echo "Native build OK"

echo ""
echo "=== Verify WASM build ==="
WASM_DIR="$DIR/build_wasm"
mkdir -p "$WASM_DIR"
EM_CONFIG=/tmp/emscripten_config emcmake cmake -S "$DIR" -B "$WASM_DIR" \
  -DCMAKE_BUILD_TYPE=Release 2>&1 | tail -5
EM_CONFIG=/tmp/emscripten_config emmake make -C "$WASM_DIR" -j"$(nproc)" 2>&1 | tail -10
echo "WASM build OK"
ls -lh "$WASM_DIR/src/openboardview/openboardview."{js,wasm}
