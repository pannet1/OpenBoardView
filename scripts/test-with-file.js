#!/usr/bin/env node
/**
 * Test loading a real .brd file into the WASM module.
 * Runs headlessly with minimal stubs.
 */
const path = require('path');
const fs = require('fs');

const WASM_DIR = path.join(__dirname, '..', 'build_wasm', 'src', 'openboardview');
const BOARD_FILE = '/tmp/test_board.brd';

if (!fs.existsSync(BOARD_FILE)) {
  console.error('Board file not found:', BOARD_FILE);
  process.exit(1);
}

// Minimal browser stubs to prevent SDL init from crashing
global.window = global;
global.document = {
  createElement: () => ({ getContext: () => null, width: 0, height: 0, style: {} }),
  getElementById: () => null,
  body: { style: {} },
  documentElement: { style: {} },
  addEventListener: () => {},
  querySelector: () => null,
  exitPointerLock: () => {},
  exitFullscreen: () => {},
};
global.screen = { width: 1280, height: 720 };
global.navigator = { userAgent: 'Node.js', platform: 'Linux', language: 'en' };
global.location = { href: '', hostname: '', pathname: '', search: '', protocol: 'file:' };
global.performance = { now: () => Date.now() };
global.setImmediate = (fn) => setTimeout(fn, 0);
global.requestAnimationFrame = (fn) => setTimeout(fn, 16);
class ImageData { constructor(w, h) { this.width = w; this.height = h; this.data = Buffer.alloc(w*h*4); } }
global.ImageData = ImageData;
global.HTMLCanvasElement = function() {};
global.HTMLImageElement = function() {};
global.HTMLVideoElement = function() {};
class MockImage {
  constructor() { this.width = 0; this.height = 0; this.src = ''; this.complete = true; this.naturalWidth = 0; this.naturalHeight = 0; }
  addEventListener(e, cb) { if (e === 'load') setTimeout(cb, 0); }
}
global.Image = MockImage;

const boardData = fs.readFileSync(BOARD_FILE);
console.log('Board file size:', boardData.length, 'bytes');

global.Module = {
  canvas: { width: 1280, height: 720, style: {} },
  locateFile: (f) => path.join(WASM_DIR, f),
  noExitRuntime: true,
  onRuntimeInitialized: () => {
    console.log('Module initialized');

    // Allocate and copy board data into WASM heap
    const ptr = Module._malloc(boardData.length);
    if (!ptr) { console.error('malloc failed'); process.exit(1); }
    Module.HEAPU8.set(boardData, ptr);

    const result = Module._loadBoardFromMemory(ptr, boardData.length);
    Module._free(ptr);

    console.log('loadBoardFromMemory result:', result);
    if (result === 0) {
      console.log('SUCCESS: Board loaded correctly');
      process.exit(0);
    } else {
      console.error('FAIL: Board load returned', result);
      process.exit(1);
    }
  },
  onAbort: (msg) => {
    console.error('Module aborted:', msg);
    process.exit(1);
  },
  print: console.log,
  printErr: console.error,
};

require(path.join(WASM_DIR, 'openboardview.js'));
