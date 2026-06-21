# OpenBoardView WASM

OpenBoardView compiled to asm.js for embedding in web apps.

## Install

```toml
# pyproject.toml
[project.dependencies]
openboardview-wasm = { git = "https://github.com/pannet1/OpenBoardView", branch = "feat/wasm-build" }
```

```bash
uv sync
```

## FastAPI — 2 lines

```python
from openboardview_wasm import make_static_files_app
app.mount("/wasm", make_static_files_app(), name="wasm")
```

This serves `openboardview.js` + `index.html` at `/wasm/` with COOP/COEP headers (required for SharedArrayBuffer).

## SPA — canvas + script

```html
<canvas id="canvas"></canvas>
<script src="/wasm/openboardview.js"></script>
<script>
  const res = Module.loadBoardFromMemory(arrayBuffer)
  // 0 = success
</script>
```

Or load from URL: `https://yourdomain/wasm/?file=https://server/board.brd`

## JS API

### `Module.loadBoardFromMemory(arrayBuffer) → number`

| Return | Meaning |
|--------|---------|
| `0` | Board loaded |
| `1` | Parse failed |
| `-1` | Invalid input |

### `Module._loadBoardFromMemory(ptr, length) → number`

Low-level. Takes a WASM heap pointer + length.

## CLI

```bash
openboardview-wasm fetch        # download pre-built JS → ./wasm/
openboardview-wasm serve        # test server on :8080
openboardview-wasm build        # build from C++ (needs Emscripten)
```

## Build from source

```bash
git clone --recurse-submodules https://github.com/pannet1/OpenBoardView
cd OpenBoardView
./scripts/build-wasm.sh
```

Output: `build_wasm/src/openboardview/openboardview.js`

## Deploy

```bash
# update your _static after rebuilding
cp build_wasm/src/openboardview/openboardview.js openboardview_wasm/_static/
```

Then commit and push. Users get the update on next `uv sync`.

## Files

| File | Description |
|------|-------------|
| `openboardview.js` | 5.6 MB asm.js (no .wasm) |
| `index.html` | Test page with `?file=` auto-load |

## Notes

- Fonts not available in browser — ImGui uses default (harmless warnings)
- SQLite annotations disabled in WASM — read-only viewer
- No file picker — load boards programmatically via JS API
