"""Regenerate Sentorr launcher assets. Requires Python 3 and Pillow."""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/branding/sentorr-icon-source.png"
ICON = Image.open(SOURCE).convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)


def save_png(path: Path, size: int, *, rounded: bool = False, source=ICON) -> None:
    image = source.convert("RGBA")
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

light = Image.open(ROOT / "assets/branding/sentorr-icon-light-source.png").convert("RGB")
light = light.resize((1024, 1024), Image.Resampling.LANCZOS)
save_png(ROOT / "assets/images/sentorr-icon-light.png", 1024, source=light)
for name, source in (("dark", ICON), ("light", light)):
    save_png(ROOT / f"assets/images/tray-{name}.png", 64, rounded=True, source=source)
    save_png(ROOT / f"assets/images/dock-{name}.png", 1024, rounded=True, source=source)
    source.save(ROOT / f"assets/images/window-{name}.ico",
                sizes=[(size, size) for size in (16, 24, 32, 48, 64, 128, 256)])

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


def save_splash(res: Path, variant: str, source) -> None:
    """Android splash icon: the mark on its own background, fitted inside the
    circle Android 12+ masks to (2/3 of the 288dp icon)."""
    background = source.getpixel((4, 4))
    distance = ImageChops.difference(source, Image.new("RGB", source.size, background))
    left, top, right, bottom = distance.convert("L").point(lambda v: 255 if v > 24 else 0).getbbox()
    mark = source.crop((left, top, right, bottom))
    side = int(((right - left) ** 2 + (bottom - top) ** 2) ** 0.5 * 1.5)
    canvas = Image.new("RGB", (side, side), background)
    canvas.paste(mark, ((side - mark.width) // 2, (side - mark.height) // 2))
    for density, scale in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
        save_png(res / f"drawable-{density}/splash_icon_{variant}.png", int(288 * scale), source=canvas)


android_res = ROOT / "android/app/src/main/res"
save_splash(android_res, "light", light)
save_splash(android_res, "dark", ICON)
# The dark launcher is the default; the app swaps to this one in light themes.
for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    save_png(android_res / f"mipmap-{density}/ic_launcher_light.png", size, source=light)

save_png(ROOT / "linux/packaging/com.sentorr.sentorr.png", 512)
print("Generated Sentorr launcher and tray icons.")
