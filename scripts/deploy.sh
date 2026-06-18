#!/usr/bin/env bash
set -euo pipefail
# Deploy WASM build output to a target directory (e.g., FastAPI static folder)
#
# Usage: ./scripts/deploy.sh [target-dir]
#   target-dir defaults to ../ecomsense-schematics/static/wasm/

DIR="$(cd "$(dirname "$0")/.." && pwd)"
WASM_DIR="$DIR/build_wasm/src/openboardview"
TARGET="${1:-$DIR/../ecomsense-schematics/static/wasm}"

if [ ! -f "$WASM_DIR/openboardview.wasm" ]; then
  echo "No WASM build found at $WASM_DIR"
  echo "Run ./scripts/build-wasm.sh first"
  exit 1
fi

mkdir -p "$TARGET"

echo "Deploying WASM build to: $TARGET"
cp -v "$WASM_DIR/openboardview.js"  "$TARGET/"
cp -v "$WASM_DIR/openboardview.wasm" "$TARGET/"
# Also copy the test HTML if needed for reference
if [ -f "$WASM_DIR/index.html" ]; then
  cp -v "$WASM_DIR/index.html" "$TARGET/"
fi

echo ""
echo "Files deployed:"
ls -lh "$TARGET"/openboardview.*
