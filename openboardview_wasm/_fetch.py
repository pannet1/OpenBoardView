import os, sys, urllib.request

REPO = "pannet1/OpenBoardView"
BRANCH = "feat/wasm-build"
BASE = f"https://raw.githubusercontent.com/{REPO}/{BRANCH}/openboardview_wasm/_static"
FILES = ["openboardview.js", "index.html"]


def fetch(target_dir="wasm"):
    os.makedirs(target_dir, exist_ok=True)
    for name in FILES:
        url = f"{BASE}/{name}"
        dst = os.path.join(target_dir, name)
        print(f"Downloading {name}...", end=" ", flush=True)
        try:
            urllib.request.urlretrieve(url, dst)
            size = os.path.getsize(dst)
            print(f"{size:,} bytes")
        except Exception as e:
            print(f"failed: {e}")
            sys.exit(1)
    print(f"\nDone. Files in {target_dir}/")
    for name in FILES:
        size = os.path.getsize(os.path.join(target_dir, name))
        print(f"  {name}  ({size:,} bytes)")
