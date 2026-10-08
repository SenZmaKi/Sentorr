"""Apply a moon badge to existing artwork in an ephemeral nightly checkout."""
from pathlib import Path
import subprocess
import sys
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SCALE = 4  # Drawn oversized, then downsampled, for smooth edges.


def disc(size, center, radius):
    mask = Image.new('L', (size, size))
    x, y = center
    ImageDraw.Draw(mask).ellipse((x - radius, y - radius, x + radius, y + radius), fill=255)
    return mask


def mark_colours(image):
    """Background from the corner; foreground is the mark's own tone."""
    background = image.getpixel((8, 8))
    pixels = [image.getpixel((x, y)) for x in range(150, 850, 6) for y in range(150, 850, 6)]
    mark = sorted((p for p in pixels if sum(abs(a - b) for a, b in zip(p, background)) > 300), key=sum)
    return background, mark[len(mark) * 3 // 4] if background[0] < 128 else mark[len(mark) // 4]


def badge(image):
    """A crescent cut from a mark-coloured disc, kept clear of the mark by a
    background-coloured gap; legible at tray sizes in both themes."""
    background, foreground = mark_colours(image)
    size = 1024 * SCALE
    canvas = image.resize((size, size), Image.Resampling.LANCZOS)
    center, radius = (812 * SCALE, 812 * SCALE), 150 * SCALE
    canvas.paste(background, (0, 0), disc(size, center, radius + 34 * SCALE))
    canvas.paste(foreground, (0, 0), disc(size, center, radius))
    moon = int(radius * 0.62)
    shadow = disc(size, (center[0] + int(moon * 0.42), center[1] - int(moon * 0.34)), int(moon * 0.84))
    canvas.paste(background, (0, 0), ImageChops.subtract(disc(size, center, moon), shadow))
    return canvas.resize((1024, 1024), Image.Resampling.LANCZOS)


for name in ('sentorr-icon-source.png', 'sentorr-icon-light-source.png'):
    path = ROOT / 'assets/branding' / name
    source = Image.open(path).convert('RGB').resize((1024, 1024), Image.Resampling.LANCZOS)
    badge(source).save(path)
subprocess.run([sys.executable, str(ROOT / 'tool/generate_icons.py')], check=True)

for relative, old, new in (
    ('android/app/src/main/AndroidManifest.xml', 'android:label="Sentorr"', 'android:label="Sentorr Nightly"'),
    ('linux/com.sentorr.sentorr.desktop', 'Name=Sentorr', 'Name=Sentorr Nightly'),
    ('scripts/setup.iss', '#define AppName "Sentorr"', '#define AppName "Sentorr Nightly"'),
):
    path = ROOT / relative
    path.write_text(path.read_text().replace(old, new))
# Keep the product/executable paths used by packaging; change the displayed name.
path = ROOT / 'macos/Runner/Info.plist'
text = path.read_text()
text = text.replace('<key>CFBundleName</key>\n\t<string>$(PRODUCT_NAME)</string>',
                    '<key>CFBundleName</key>\n\t<string>Sentorr Nightly</string>')
path.write_text(text)

subprocess.run([sys.executable, str(ROOT / 'tool/release/nightly_identity.py')], check=True)
