"""CI override; local development keeps the sibling checkout."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[2]
native = root / 'native/libtorrent_dart'
lock = (root / 'pubspec.lock').read_text()
pin = re.search(r'\n  libtorrent_dart:\n(?:    .*\n)*?    version: "([^"]+)"', lock)[1]
version = re.search(r'^version:\s*(\S+)', (native / 'pubspec.yaml').read_text(), re.M)[1]
if version != pin:
    raise SystemExit(f'Native source {version} does not match locked libtorrent_dart {pin}')
(root / 'pubspec_overrides.yaml').write_text(
    'dependency_overrides:\n  libtorrent_dart:\n    path: native/libtorrent_dart\n')

import os
if os.environ.get('GITHUB_ENV'):
    with open(os.environ['GITHUB_ENV'], 'a') as environment:
        environment.write(f'BINDING_VERSION={version}\n')
