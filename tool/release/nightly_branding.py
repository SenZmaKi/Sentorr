"""Apply a moon badge to existing artwork in an ephemeral nightly checkout."""
from pathlib import Path
import subprocess
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
for name in ('sentorr-icon-source.png', 'sentorr-icon-light-source.png'):
    path = ROOT / 'assets/branding' / name
    image = Image.open(path).convert('RGB').resize((1024, 1024))
    draw = ImageDraw.Draw(image)
    # The crescent remains recognizable in monochrome tray and launcher sizes.
    draw.ellipse((660, 660, 1000, 1000), fill='#171717', outline='#FFFFFF', width=24)
    draw.ellipse((730, 720, 930, 930), fill='#FFFFFF')
    draw.ellipse((800, 690, 960, 850), fill='#171717')
    image.save(path)
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
