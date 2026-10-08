"""Configuration edits must preserve existing release feeds on Pages."""
from pathlib import Path
from urllib.request import urlopen
from urllib.error import HTTPError
import subprocess

root = Path(__file__).resolve().parents[2]
site = root / 'site'
site.mkdir(exist_ok=True)
(site / '.nojekyll').touch()
signer = root / 'source-directory/signer'
subprocess.run(['dart','run','bin/sign.dart','--input','../source_directory.payload.json',
    '--output',str(site/'source-directory.json')],cwd=signer,check=True)
for name in ['update-manifest.json','appcast.xml','appcast-prerelease.xml','appcast-nightly.xml']:
    try:
        with urlopen('https://senzmaki.github.io/Sentorr/'+name) as response:
            (site/name).write_bytes(response.read())
    except HTTPError as error:
        if error.code != 404:
            raise
        if name == 'update-manifest.json':
            subprocess.run(['dart','run','bin/sign.dart','--input','../../update-manifest/update_manifest.payload.json',
                '--output',str(site/name),'--private-key-environment','UPDATE_MANIFEST_PRIVATE_KEY'],cwd=signer,check=True)
# A successful HTTP response is not proof that a feed has a trusted signature.
subprocess.run(['dart','run','bin/verify.dart','--input',str(site/'update-manifest.json'),
    '--output',str(site/'verified-manifest.payload.json'),'--public-key',
    (root/'update-manifest/public-key.txt').read_text().strip()],cwd=signer,check=True)
(site/'verified-manifest.payload.json').unlink()
