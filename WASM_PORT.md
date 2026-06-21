# OpenBoardView WASM Port

OpenBoardView compiled to WebAssembly (asm.js) for embedding in web applications.

## Quick Start

```bash
# Install
pip install openboardview-wasm

# Run standalone server
openboardview-wasm 8080
# → http://localhost:8080/?file=/test.brd

# Or mount in your FastAPI app
```

## Files

| File | Size | Description |
|------|------|-------------|
| `openboardview.js` | 5.6 MB | Emscripten asm.js build (no .wasm file needed) |
| `index.html` | ~1 KB | Example page with `?file=` auto-load support |

No WebAssembly `.wasm` file — the entire app is in the single `.js` file.

## Build from Source

Requires Emscripten SDK:

```bash
git clone --recurse-submodules https://github.com/pannet1/OpenBoardView
cd OpenBoardView
./scripts/build-wasm.sh
```

Output: `build_wasm/src/openboardview/openboardview.js`

### Build flags

- **`WASM=0`**: Build as asm.js (not pure wasm). Required because the Emscripten linker eliminates indirect function call table entries needed by the C++ file format parsers.
- **`-O2`**: Required to prevent `about:blank` navigation in the browser.
- **SDL2, SQLite3, zlib**: Linked via Emscripten system ports.

## Embedding in FastAPI

### 1. Install the package

```bash
pip install openboardview-wasm
```

### 2. Mount in your app

```python
from fastapi import FastAPI
from openboardview_wasm import make_static_files_app

app = FastAPI()

# Serve OpenBoardView at /wasm
app.mount("/wasm", make_static_files_app(), name="wasm")
```

The `make_static_files_app()` function returns a Starlette `StaticFiles` instance wrapped with COOP/COEP headers (`same-origin` + `require-corp`) required for `SharedArrayBuffer` support.

### 3. Use from your frontend

```html
<script>
const module = await new Promise((resolve) => {
  const m = { onRuntimeInitialized: () => resolve(m) };
  const s = document.createElement('script');
  s.src = '/wasm/openboardview.js';
  document.head.appendChild(s);
});

// Load a .brd file from your server
const resp = await fetch('https://your-server.com/boards/board.brd');
const buf = await resp.arrayBuffer();
const result = module.loadBoardFromMemory(buf);
console.log('Load result:', result); // 0 = success
</script>
```

### 4. Or via query parameter

```
https://yourdomain.com/wasm/?file=https://server/board.brd
```

The index.html will auto-fetch and load the board after module init.

### 5. COOP/COEP Headers

If you mount the app globally (not in a sub-path), ensure your FastAPI middleware adds these headers:

```python
@app.middleware("http")
async def add_coop_coep(request, call_next):
    response = await call_next(request)
    response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
    response.headers["Cross-Origin-Embedder-Policy"] = "require-corp"
    return response
```

The `make_static_files_app()` helper adds these automatically for the `/wasm` path.

## JavaScript API

### `Module.loadBoardFromMemory(arrayBuffer) → number`

| Return | Meaning |
|--------|---------|
| `0` | Board loaded successfully |
| `1` | Format not recognized or parse failed |
| `-1` | Null input or empty data |
| `-2` | Buffer allocation failed |

### `Module._loadBoardFromMemory(ptr, length) → number`

Low-level version — takes a WASM heap pointer and length. Used internally by the wrapper.

## Standalone Test Server

```bash
# Using the installed package
openboardview-wasm 8080

# Using the repo scripts
./scripts/serve.sh 8080

# Or directly with Python
python3 test_server.py 8080
```

## Deploy

```bash
./scripts/build-wasm.sh
./scripts/deploy.sh /path/to/your/static/wasm
```

Or just copy the files manually:

```bash
cp build_wasm/src/openboardview/openboardview.js your-static-dir/
cp build_wasm/src/openboardview/index.html your-static-dir/
```

## Architecture

```
                    ┌─────────────────────────┐
                    │     Browser (Canvas)     │
                    │   WebGL ── ImGui ── SDL2 │
                    └──────────┬──────────────┘
                               │ loadBoardFromMemory(arrayBuffer)
                    ┌──────────▼──────────────┐
                    │   openboardview.js       │
                    │   (Emscripten asm.js)    │
                    └──────────┬──────────────┘
                               │ C++ API
                    ┌──────────▼──────────────┐
                    │   BoardView              │
                    │   ├─ LoadFromBuffer()    │
                    │   ├─ File format parsers │
                    │   │  (BRD2File, etc.)    │
                    │   └─ ImGui renderer      │
                    └─────────────────────────┘
```

## Limitations

- **Fonts**: System fonts not available in browser — ImGui uses default font (harmless warnings)
- **Annotations**: SQLite annotation DB disabled in WASM (read-only viewer)
- **File picker**: Not implemented — use the JS API to load boards programmatically
- **Performance**: asm.js is ~2x larger than pure wasm but avoids function pointer table issues

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Page navigates to `about:blank` | Missing `-O2` flag | Add `-O2` to both compile and link flags |
| `null function` error | WASM function table elimination | Use `WASM=0` (asm.js build) |
| `canvas is undefined` | No `<canvas>` element in HTML | Add `<canvas id="canvas">` and `Module.canvas = ...` |
| `loadBoardFromMemory` not a function | Module not initialized | Wait for `onRuntimeInitialized` or poll for `Module._loadBoardFromMemory` |
| CORS/COOP error | Missing security headers | Add COOP/COEP headers to server response |

## License

MIT (upstream OpenBoardView: GPL-3.0)
