VERSION = "0.1.0"

from ._app import make_static_files_app, DEFAULT_WASM_DIR as STATIC_DIR

__all__ = ["make_static_files_app", "STATIC_DIR", "VERSION"]
