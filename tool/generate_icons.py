"""Regenerate Sentorr launcher assets. Requires Python 3 and Pillow."""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/branding/sentorr-icon-source.png"
ICON = Image.open(SOURCE).convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)


def save_png(path: Path, size: int, *, rounded: bool = False) -> None:
    image = ICON.convert("RGBA")
    if rounded:
        mask = Image.new("L", image.size)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, 1023, 1023), radius=220, fill=255)
        image.putalpha(mask)
        # Desktop icons need breathing room around the rounded tile.
        canvas = Image.new("RGBA", image.size)
        tile = image.resize((824, 824), Image.Resampling.LANCZOS)
        canvas.paste(tile, (100, 100), tile)
        image = canvas
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(path)


save_png(ROOT / "assets/images/sentorr-icon.png", 1024)
save_png(ROOT / "assets/images/tray.png", 64, rounded=True)

for app in (ROOT, ROOT / "tool/design_demo", ROOT / "tool/codec_lab"):
    mac_icons = app / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    if mac_icons.exists():
        for size in (16, 32, 64, 128, 256, 512, 1024):
            save_png(mac_icons / f"app_icon_{size}.png", size, rounded=True)
    windows_icon = app / "windows/runner/resources/app_icon.ico"
    if windows_icon.parent.exists():
        ICON.save(windows_icon, sizes=[(size, size) for size in (16, 24, 32, 48, 64, 128, 256)])
    android_res = app / "android/app/src/main/res"
    if android_res.exists():
        for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                              "xxhdpi": 144, "xxxhdpi": 192}.items():
            save_png(android_res / f"mipmap-{density}/ic_launcher.png", size)

save_png(ROOT / "linux/packaging/com.sentorr.sentorr.png", 512)
print("Generated Sentorr launcher and tray icons.")
