"""CI override; local development keeps the sibling checkout."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[2]
native = root / 'native/libtorrent_dart'
text = (root / 'pubspec.yaml').read_text()
pin = re.search(r'ref:\s*([a-f0-9]{40})', text)[1]
import subprocess
actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=native, text=True).strip()
if actual != pin:
    raise SystemExit('Native source does not match pubspec pin')
(root / 'pubspec_overrides.yaml').write_text(
    'dependency_overrides:\n  libtorrent_dart:\n    path: native/libtorrent_dart\n')

import os
version = re.search(r'^version:\s*(\S+)', (native / 'pubspec.yaml').read_text(), re.M)[1]
if os.environ.get('GITHUB_ENV'):
    with open(os.environ['GITHUB_ENV'], 'a') as environment:
        environment.write(f'BINDING_VERSION={version}\n')
