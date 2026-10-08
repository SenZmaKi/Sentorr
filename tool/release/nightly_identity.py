"""Separate native nightly application identity in the CI checkout."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace(relative, before, after):
    path = ROOT / relative
    text = path.read_text()
    if before not in text:
        raise ValueError(f'{relative}: expected identity marker not found: {before}')
    path.write_text(text.replace(before, after))


replace('android/app/build.gradle.kts', 'applicationId = "com.sentorr.sentorr"',
        'applicationId = "com.sentorr.sentorr.nightly"')
# Classes and launcher aliases remain in the Kotlin namespace.
manifest = 'android/app/src/main/AndroidManifest.xml'
for name in ('MainActivity', 'ReturnActivity', 'LauncherDark', 'LauncherLight'):
    replace(manifest, f'".{name}"', f'"com.sentorr.sentorr.{name}"')
replace(manifest, 'android:scheme="sentorr"', 'android:scheme="sentorr-nightly"')
replace('macos/Runner/Configs/AppInfo.xcconfig',
        'PRODUCT_BUNDLE_IDENTIFIER = com.sentorr.sentorr',
        'PRODUCT_BUNDLE_IDENTIFIER = com.sentorr.sentorr.nightly')
replace('linux/CMakeLists.txt', 'set(APPLICATION_ID "com.sentorr.sentorr")',
        'set(APPLICATION_ID "com.sentorr.sentorr.nightly")')
replace('linux/com.sentorr.sentorr.desktop', 'Icon=com.sentorr.sentorr',
        'Icon=com.sentorr.sentorr.nightly')
replace('scripts/setup.iss', 'AppId={{CA87E71C-663D-422E-930E-181CB50C0021}',
        'AppId={{BBFCAD87-C1F7-4713-8C8A-5B345B8904C9}')
replace('windows/runner/Runner.rc', '"CompanyName", "com.sentorr"',
        '"CompanyName", "com.sentorr.sentorr.nightly"')
for field in ('FileDescription', 'ProductName'):
    replace('windows/runner/Runner.rc', f'"{field}", "Sentorr"',
            f'"{field}", "Sentorr Nightly"')
replace('scripts/setup.iss',
        r'"{userappdata}\\com.sentorr.sentorr\\Sentorr\\SentorrData"',
        r'"{userappdata}\\com.sentorr.sentorr.nightly\\Sentorr Nightly\\SentorrNightlyData"')
