#!/usr/bin/env node
/**
 * Headless smoke test for OpenBoardView WASM module.
 * Verifies the module loads and loadBoardFromMemory handles error cases.
 */
const path = require('path');
const fs = require('fs');

const WASM_DIR = path.join(__dirname, '..', 'build_wasm', 'src', 'openboardview');
const jsPath = path.join(WASM_DIR, 'openboardview.js');
const wasmPath = path.join(WASM_DIR, 'openboardview.wasm');

if (!fs.existsSync(jsPath) || !fs.existsSync(wasmPath)) {
  console.error('Build not found. Run ./scripts/build-wasm.sh first.');
  process.exit(1);
}

// Minimal environment for Emscripten to not crash on missing browser APIs
global.window = global;
global.document = {
  createElement: () => ({
    getContext: () => null,
    width: 0, height: 0,
    style: {},
  }),
  getElementById: () => null,
  body: { style: {} },
  documentElement: { style: {} },
  createEvent: () => ({ initEvent: () => {} }),
  addEventListener: () => {},
  exitPointerLock: () => {},
  exitFullscreen: () => {},
  querySelector: () => null,
};
global.screen = { width: 1280, height: 720 };
global.navigator = {
  userAgent: 'Node.js',
  platform: 'Linux',
  language: 'en',
};
global.location = { href: '', hostname: '', pathname: '', search: '', protocol: 'file:' };
global.performance = { now: () => Date.now() };
global.setImmediate = (fn) => setTimeout(fn, 0);
global.requestAnimationFrame = (fn) => setTimeout(fn, 16);

// Image/HTMLCanvasElement stubs
class ImageData {
  constructor(w, h) { this.width = w; this.height = h; this.data = Buffer.alloc(w * h * 4); }
}
global.ImageData = ImageData;
global.HTMLCanvasElement = function() {};
global.HTMLImageElement = function() {};
global.HTMLVideoElement = function() {};

class MockImage {
  constructor() { this.width = 0; this.height = 0; this.src = ''; }
  addEventListener(e, cb) { if (e === 'load') setTimeout(cb, 0); }
}
global.Image = MockImage;

// Module config
global.Module = {
  canvas: { width: 1280, height: 720, style: {} },
  locateFile: (f) => path.join(WASM_DIR, f),
  onRuntimeInitialized: () => {
    console.log('Module initialized');

    // Test 1: null buffer
    console.log('Test 1: null buffer =>', Module._loadBoardFromMemory(0, 0));

    // Test 2: empty data
    const empty = Module._malloc(1);
    console.log('Test 2: empty data =>', Module._loadBoardFromMemory(empty, 0));
    Module._free(empty);

    // Test 3: random garbage (should return 1 = unrecognized format)
    const garbage = Module._malloc(100);
    for (let i = 0; i < 100; i++) Module.HEAPU8[garbage + i] = i;
    console.log('Test 3: garbage data =>', Module._loadBoardFromMemory(garbage, 100));
    Module._free(garbage);

    console.log('All tests passed (no crashes).');
    process.exit(0);
  },
  onAbort: (msg) => {
    console.error('Module aborted:', msg);
    process.exit(1);
  }
};

console.log('Loading', jsPath);
require(jsPath);
