#!/usr/bin/env python3
"""Build the owned bridge into the version/architecture used by native assets."""
from pathlib import Path
import os
import platform
import re
import subprocess
import sys

if len(sys.argv) != 2:
    raise SystemExit('Usage: python3 tool/build_native.py /absolute/path/to/libtorrent_dart')
repo = Path(sys.argv[1]).resolve()
version = re.search(r'^version:\s*(\S+)', (repo / 'pubspec.yaml').read_text(), re.M)[1]
system = {'Darwin': 'macos', 'Linux': 'linux', 'Windows': 'windows'}[platform.system()]
architecture = {'arm64': 'arm64', 'aarch64': 'arm64', 'x86_64': 'x64', 'AMD64': 'x64'}[platform.machine()]
preset = f'{system}-{architecture}'
subprocess.run(['cmake', '--preset', preset, f'-DLTD_BINARY_LAYOUT_VERSION={version}',
    '-DCMAKE_C_COMPILER_LAUNCHER=', '-DCMAKE_CXX_COMPILER_LAUNCHER='], cwd=repo, check=True)
subprocess.run(['cmake', '--build', '--preset', preset, '--parallel',
    str(min(6, os.cpu_count() or 2))], cwd=repo, check=True)
