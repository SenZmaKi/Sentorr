"""Do not erase the other macOS channel when deploying a release feed."""
import sys
from pathlib import Path
from urllib.request import urlopen
from urllib.error import HTTPError
site = Path(sys.argv[1])
channel = sys.argv[2]
if channel == 'prerelease':
    name = 'appcast.xml'
    try:
        with urlopen('https://senzmaki.github.io/Sentorr/' + name) as response:
            (site / name).write_bytes(response.read())
    except HTTPError as error:
        if error.code != 404:
            raise
