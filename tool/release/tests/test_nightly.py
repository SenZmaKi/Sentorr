"""Release plumbing regressions; no network or signing secrets required."""
import io
import runpy
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]


class NightlyReleaseTests(unittest.TestCase):
    def test_each_channel_preserves_other_appcasts(self):
        for channel, current in (('stable', 'appcast.xml'),
                                 ('prerelease', 'appcast-prerelease.xml'),
                                 ('nightly', 'appcast-nightly.xml')):
            with self.subTest(channel=channel), tempfile.TemporaryDirectory() as directory:
                with patch.object(sys, 'argv', ['preserve', directory, channel]), \
                     patch('urllib.request.urlopen', side_effect=lambda *a, **k: io.BytesIO(b'feed')):
                    runpy.run_path(str(ROOT / 'tool/release/preserve_appcast.py'))
                names = {p.name for p in Path(directory).iterdir()}
                self.assertEqual(names, {'appcast.xml', 'appcast-prerelease.xml',
                                         'appcast-nightly.xml'} - {current})

    def test_branding_generates_assets_in_scratch_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for relative in ('tool/release/nightly_branding.py', 'tool/release/nightly_identity.py', 'tool/generate_icons.py',
                             'android/app/build.gradle.kts', 'linux/CMakeLists.txt', 'windows/runner/Runner.rc',
                             'macos/Runner/Configs/AppInfo.xcconfig',
                             'android/app/src/main/AndroidManifest.xml',
                             'linux/com.sentorr.sentorr.desktop', 'scripts/setup.iss',
                             'macos/Runner/Info.plist', 'assets/branding/sentorr-icon-source.png',
                             'assets/branding/sentorr-icon-light-source.png'):
                destination = root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, destination)
            (root / 'android/app/src/main/res').mkdir(parents=True)
            (root / 'windows/runner/resources').mkdir(parents=True)
            (root / 'macos/Runner/Assets.xcassets/AppIcon.appiconset').mkdir(parents=True)
            runpy.run_path(str(root / 'tool/release/nightly_branding.py'))
            for asset in ('assets/images/tray-dark.png', 'assets/images/dock-light.png',
                          'assets/images/window-dark.ico', 'windows/runner/resources/app_icon.ico',
                          'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
                          'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png'):
                self.assertTrue((root / asset).is_file(), asset)
            self.assertIn('com.sentorr.sentorr.nightly', (root / 'android/app/build.gradle.kts').read_text())
            self.assertIn('com.sentorr.sentorr.nightly', (root / 'macos/Runner/Configs/AppInfo.xcconfig').read_text())
            self.assertIn('sentorr-nightly', (root / 'android/app/src/main/AndroidManifest.xml').read_text())
            self.assertIn('SentorrNightlyData', (root / 'scripts/setup.iss').read_text())
            self.assertNotIn('CA87E71C-663D-422E-930E-181CB50C0021', (root / 'scripts/setup.iss').read_text())
            self.assertIn('Sentorr Nightly', (root / 'macos/Runner/Info.plist').read_text())
            self.assertNotEqual((root / 'assets/images/sentorr-icon.png').read_bytes(),
                                (ROOT / 'assets/images/sentorr-icon.png').read_bytes())


if __name__ == '__main__':
    unittest.main()
