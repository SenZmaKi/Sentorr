#!/usr/bin/env python3
"""Check the real macOS startup/raster handshake without showing a window.

First run: flutter build macos --debug --no-pub
Then: python3 tool/startup/smoke.py
Uses an isolated, temporarily re-identified copy of the debug app and settings.
"""
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import time
import uuid

source = Path("build/macos/Build/Products/Debug/Sentorr.app").resolve()
assert source.is_dir(), "Build the debug macOS app first"
with tempfile.TemporaryDirectory(prefix="sentorr-startup-") as temporary:
    root = Path(temporary)
    app = root / "Sentorr.app"
    subprocess.run(["cp", "-cR", str(source), str(app)], check=True)
    identifier = "com.sentorr.startup-smoke-" + uuid.uuid4().hex
    info = app / "Contents/Info.plist"
    with info.open("rb") as handle:
        metadata = plistlib.load(handle)
    metadata["CFBundleIdentifier"] = identifier
    with info.open("wb") as handle:
        plistlib.dump(metadata, handle)
    entitlements = root / "entitlements.plist"
    with entitlements.open("wb") as handle:
        plistlib.dump({"com.apple.security.cs.allow-jit": True}, handle)
    subprocess.run([
        "codesign", "--force", "--sign", "-", "--entitlements", str(entitlements), str(app)
    ], check=True, capture_output=True)
    support = Path.home() / "Library/Application Support" / identifier
    settings = support / "SentorrData/settings/settings.json"
    settings.parent.mkdir(parents=True)
    try:
        for mode, white in [("light", "1.0"), ("dark", "0.0")]:
            settings.write_text(json.dumps({"themeMode": mode}))
            log = root / f"{mode}.log"
            with log.open("w") as output:
                process = subprocess.Popen(
                    [str(app / "Contents/MacOS" / metadata["CFBundleExecutable"])],
                    env={**os.environ, "SENTORR_STARTUP_SMOKE": "1"},
                    stdout=output, stderr=output,
                )
                try:
                    deadline = time.monotonic() + 45
                    while time.monotonic() < deadline:
                        contents = log.read_text(errors="replace")
                        if "SENTORR_STARTUP_READY" in contents:
                            marker = next(line for line in contents.splitlines()
                                          if "SENTORR_STARTUP_READY" in line)
                            assert "visible=false" in marker, marker
                            assert f"white={white}" in marker, marker
                            print(f"PASS {mode}: first app frame rasterized; native window hidden; fallback matches")
                            break
                        assert process.poll() is None, contents[-5000:]
                        time.sleep(0.1)
                    else:
                        raise AssertionError(f"Startup did not reach reveal:\n{contents[-5000:]}")
                finally:
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
    finally:
        shutil.rmtree(support, ignore_errors=True)
        shutil.rmtree(Path.home() / "Library/Caches" / identifier, ignore_errors=True)
        (Path.home() / "Library/Preferences" / f"{identifier}.plist").unlink(missing_ok=True)
