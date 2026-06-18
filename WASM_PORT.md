# OpenBoardView WASM Port

Port of OpenBoardView to WebAssembly for embedding in SPAs (e.g., ecomsense.in/schematics).

Scripts for common operations are in `scripts/`:
- `build-wasm.sh` — build WASM
- `serve.sh` — start test server
- `deploy.sh` — copy files to FastAPI static dir
- `merge-upstream.sh` — merge upstream + verify both builds

## Workflow

Scripts should be run in this order depending on what you're doing:

### Development (iterate on code → test in browser)
```
1. ./scripts/build-wasm.sh   # after C++ changes
2. ./scripts/serve.sh        # start test server, then open http://localhost:8080
```

### Deploy (release to FastAPI SPA)
```
1. ./scripts/build-wasm.sh   # fresh production build
2. ./scripts/deploy.sh       # copies .js + .wasm to FastAPI static dir
```

### Maintenance (merge upstream changes)
```
1. ./scripts/merge-upstream.sh   # fetch, merge, build native + wasm to verify
```

### First-time setup (only once)
```
# Create writable Emscripten config
cp /usr/share/emscripten/.emscripten /tmp/emscripten_config
# Edit /tmp/emscripten_config and set FROZEN_CACHE = False

# Then build
./scripts/build-wasm.sh
```

## Build

```bash
# Quick start (script)
./scripts/build-wasm.sh

# Or manually:
mkdir -p build_wasm
EM_CONFIG=/tmp/emscripten_config emcmake cmake -S . -B build_wasm \
  -DCMAKE_BUILD_TYPE=Release
EM_CONFIG=/tmp/emscripten_config emmake make -C build_wasm -j$(nproc)
```

Output: `build_wasm/src/openboardview/openboardview.{js,wasm}` (~2.8 MB wasm, ~190 KB js).

**Emscripten config** (`/tmp/emscripten_config`): copy from `/usr/share/emscripten/.emscripten`, set `FROZEN_CACHE = False` so port downloads are cached.

## JS API

The `Module` object exposes one function for loading board files:

### `Module.loadBoardFromMemory(arrayBuffer)`

| Param        | Type          | Description                |
|-------------|---------------|----------------------------|
| arrayBuffer | `ArrayBuffer` | Raw board file bytes       |
| Returns     | `number`      | `0`=success, `1`=fail, `-1`=error |

Convenience wrapper (set up in `onRuntimeInitialized`):

```javascript
Module.loadBoardFromMemory = function(arrayBuffer) {
  if (!arrayBuffer || !arrayBuffer.byteLength) return -1;
  var data = new Uint8Array(arrayBuffer);
  var ptr = Module._malloc(data.length);
  if (!ptr) return -1;
  Module.HEAPU8.set(data, ptr);
  var result = Module._loadBoardFromMemory(ptr, data.length);
  Module._free(ptr);
  return result;
};
```

### Module setup for the SPA

```html
<canvas id="canvas"></canvas>
<script>
var Module = {
  canvas: document.getElementById('canvas'),
  locateFile: function(path) { return '/static/wasm/' + path; },
  onRuntimeInitialized: function() {
    Module.loadBoardFromMemory = function(arrayBuffer) {
      if (!arrayBuffer || !arrayBuffer.byteLength) return -1;
      var data = new Uint8Array(arrayBuffer);
      var ptr = Module._malloc(data.length);
      if (!ptr) return -1;
      Module.HEAPU8.set(data, ptr);
      var result = Module._loadBoardFromMemory(ptr, data.length);
      Module._free(ptr);
      return result;
    };
  }
};
</script>
<script src="/static/wasm/openboardview.js"></script>
```

## FastAPI Integration (ecomsense.in/schematics)

### 1. Serve WASM files statically

Place `openboardview.js` and `openboardview.wasm` in your static directory and mount them:

```python
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# Serve WASM files (no COOP/COEP needed for static files themselves,
# but the page that loads them must have the headers)
app.mount("/static/wasm", StaticFiles(directory="static/wasm"), name="wasm")
```

### 2. Apply COOP/COEP headers to the page

SharedArrayBuffer (used by Emscripten with ALLOW_MEMORY_GROWTH) requires both headers.
Add a middleware or set them on the HTML response:

```python
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware

# If serving SPA via FastAPI:
@app.get("/schematics")
async def get_schematics():
    headers = {
        "Cross-Origin-Opener-Policy": "same-origin",
        "Cross-Origin-Embedder-Policy": "require-corp",
    }
    with open("templates/schematics.html") as f:
        return HTMLResponse(content=f.read(), headers=headers)
```

If your SPA is served by a different server (nginx, etc.), add headers there:

```nginx
location /schematics {
    add_header Cross-Origin-Opener-Policy "same-origin";
    add_header Cross-Origin-Embedder-Policy "require-corp";
}
```

### 3. Board file endpoint

Create a FastAPI endpoint that returns board files:

```python
from fastapi.responses import FileResponse

@app.get("/api/boards/{board_id}")
async def get_board(board_id: str):
    path = f"/path/to/boards/{board_id}"
    # Board files must also have COEP header for fetch to work
    headers = {"Cross-Origin-Resource-Policy": "cross-origin"}
    return FileResponse(path, headers=headers)
```

### 4. SPA JavaScript integration

```javascript
async function loadBoard(boardId) {
  const resp = await fetch(`/api/boards/${boardId}`);
  const buf = await resp.arrayBuffer();
  const result = Module.loadBoardFromMemory(buf);
  if (result === 0) {
    console.log('Board loaded successfully');
  } else {
    console.error('Failed to load board:', result);
  }
}
```

## Testing

### Local test server

```bash
# Quick start (script)
./scripts/serve.sh [port]

# Or manually:
# Python (recommended)
python3 test_server.py 8080

# C++ (if compiled)
./build_wasm/src/openboardview/wasm_server 8080 build_wasm/src/openboardview/
```

Open http://localhost:8080. You should see the OpenBoardView GUI (ImGui UI with menu bar).

### Manual browser test

1. Open http://localhost:8080
2. Wait for "Module.loadBoardFromMemory(arrayBuffer) ready" in console
3. Load a board file (e.g., from `/usr/share/OpenBoardView/samples/`):
   ```js
   fetch('test_board.brd')
     .then(r => r.arrayBuffer())
     .then(buf => Module.loadBoardFromMemory(buf))
     .then(console.log)
   ```
4. If you don't have a board file, test with error handling:
   ```js
   // Should print 1 (fail - unrecognized format or empty)
   Module.loadBoardFromMemory(new ArrayBuffer(10))
   ```

### What to verify in the browser

- OpenBoardView 10.0.0 renders in the canvas (ImGui UI visible)
- Console shows font "not found" messages (expected — harmless)
- No `abort()` or runtime errors
- `Module.loadBoardFromMemory` returns 0 on valid board file
- Board data appears in the viewer after loading

## Key Design Decisions

### All changes are `#ifdef __EMSCRIPTEN__` guarded
- `main_opengl.cpp`: main loop uses `emscripten_set_main_loop_arg` instead of `while(!done)`
- `ImGuiRendererSDL.cpp`: `SDL_GL_SetSwapInterval(1)` skipped (calls `emscripten_set_main_loop_timing` before main loop exists)
- `CMakeLists.txt`: SDL2/SQLite3/zlib from Emscripten ports; no fontconfig/GTK/GIO/PDFBridge
- `BoardView.cpp`: `LoadFromBuffer` method added for buffer-based file loading

### Bug fixes that apply to all platforms (not Emscripten-guarded)
- `Config::SetXZZPCBKey()` — early return on empty string to avoid `std::stoul("")` abort
- `Confparse` struct — added default member initializers (`= nullptr`, `= 0`); `conf` was uninitialized
- `BoardView` heap-allocated via `std::make_unique<BoardView>()` — struct too large for 64 KB stack

### New files
| File | Purpose |
|------|---------|
| `src/openboardview/emscripten_platform.cpp` | Stubs: `show_file_picker`, `get_font_path`, `load_font`, `get_user_dir` |
| `cmake/wasm_server.cpp` | Zero-dependency C++ HTTP server with COOP/COEP |
| `test_server.py` | Python HTTP server with COOP/COEP |
| `WASM_PORT.md` | This file |

### Emscripten linker flags
```
-s USE_SDL=2 -s USE_SQLITE3=1 -s USE_ZLIB=1
-s ALLOW_MEMORY_GROWTH=1
-s WASM=1
-s STACK_SIZE=5MB
-s EXPORTED_RUNTIME_METHODS=ccall,cwrap
```

`-s USE_*` flags must be in BOTH `CMAKE_CXX_FLAGS` and `CMAKE_EXE_LINKER_FLAGS`.

## Working with the Upstream Project

### Branch strategy

- `main`: your working branch, can merge `feat/wasm-build` into it
- `feat/wasm-build`: WASM port feature branch
- To test upstream compatibility: create a throwaway branch, merge upstream `main` into it, build native

### Merging upstream changes

When upstream releases new commits:

```bash
# Add upstream remote (one-time)
git remote add upstream https://github.com/OpenBoardView/OpenBoardView.git

# Fetch and merge
git fetch upstream
git merge upstream/main
# Resolve conflicts, then:
# - Native build: verify `#ifdef __EMSCRIPTEN__` blocks still compile-skip
# - WASM build: rebuild with emcmake/emmake
```

### Common conflict areas

| File | Conflict pattern |
|------|-----------------|
| `CMakeLists.txt` | Upstream changes GL/PkgConfig logic; our `elseif(EMSCRIPTEN)` block must stay |
| `main_opengl.cpp` | Upstream changes main loop; our `__EMSCRIPTEN__` guard on `while(!done)` must stay |
| `BoardView.cpp` | Upstream changes `LoadFile`; `LoadFromBuffer` is a new method, should merge cleanly |
| `ImGuiRendererSDL.cpp` | VSync guard on `SDL_GL_SetSwapInterval` |

### Verify after merge

```bash
# Native build
mkdir -p build_native && cd build_native
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

# WASM build
cd ..
EM_CONFIG=/tmp/emscripten_config emcmake cmake -S . -B build_wasm -DCMAKE_BUILD_TYPE=Release
EM_CONFIG=/tmp/emscripten_config emmake make -C build_wasm -j$(nproc)
```

## Known Issues

- **Fonts not found**: `get_font_path()` returns empty on Emscripten. The app logs "not found" per font attempt but renders fine with ImGui's built-in font.
- **WASM binary size**: ~2.8 MB. Could reduce with `-s SIDE_MODULE` or stripping unused SDL2/ImGui features.
- **No file picker**: `show_file_picker()` is a stub; files must be loaded via JS API.
- **Board window title**: not set when loading from buffer (no filename).
- **COOP/COEP required**: the hosting page MUST send both headers for SharedArrayBuffer (used by `ALLOW_MEMORY_GROWTH`).
