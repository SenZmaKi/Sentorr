"""Preserve the other macOS channels when deploying a release feed."""
import sys
from pathlib import Path
from urllib.request import urlopen
from urllib.error import HTTPError

site = Path(sys.argv[1])
current = {'stable': 'appcast.xml', 'prerelease': 'appcast-prerelease.xml',
           'nightly': 'appcast-nightly.xml'}[sys.argv[2]]
for name in ('appcast.xml', 'appcast-prerelease.xml', 'appcast-nightly.xml'):
    if name == current:
        continue
    try:
        with urlopen('https://senzmaki.github.io/Sentorr/' + name, timeout=30) as response:
            (site / name).write_bytes(response.read())
    except HTTPError as error:
        if error.code != 404:
            raise
