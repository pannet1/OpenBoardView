import os, pathlib
from starlette.staticfiles import StaticFiles

DEFAULT_WASM_DIR = pathlib.Path(__file__).parent / "_static"


def _static_dir():
    return os.environ.get("OPENBOARDVIEW_WASM_DIR") or str(DEFAULT_WASM_DIR)


def make_static_files_app(static_dir=None, *, coop_coep=True):
    """Create a Starlette StaticFiles app that serves the OpenBoardView files.

    Usage in FastAPI:
        from openboardview_wasm import make_static_files_app
        app.mount("/wasm", make_static_files_app(), name="wasm")
    """
    if static_dir is None:
        static_dir = _static_dir()

    inner = StaticFiles(directory=str(static_dir), html=True, check_dir=False)

    if not coop_coep:
        return inner

    class COOPCOEPWrapper:
        def __init__(self, app):
            self.app = app

        async def __call__(self, scope, receive, send):
            async def send_wrapper(message):
                if message["type"] == "http.response.start":
                    headers = list(message.get("headers", []))
                    headers.append(
                        (b"cross-origin-opener-policy", b"same-origin")
                    )
                    headers.append(
                        (b"cross-origin-embedder-policy", b"require-corp")
                    )
                    headers.append(
                        (b"access-control-allow-origin", b"*")
                    )
                    message["headers"] = headers
                await send(message)
            await self.app(scope, receive, send_wrapper)

    return COOPCOEPWrapper(inner)
