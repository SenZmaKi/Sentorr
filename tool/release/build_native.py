"""Build matching streaming symbols before Flutter resolves native assets."""
import os
from pathlib import Path
import platform
import re
import subprocess
import tarfile
import urllib.request

root = Path(__file__).resolve().parents[2]
repo = root / 'native/libtorrent_dart'
version = re.search(r'^version:\s*(\S+)', (repo / 'pubspec.yaml').read_text(), re.M)[1]
system = platform.system()
arch = {'arm64': 'arm64', 'aarch64': 'arm64', 'x86_64': 'x64', 'AMD64': 'x64', 'ARM64': 'arm64'}[platform.machine()]
if os.environ.get('ANDROID_NDK_HOME') and os.environ.get('SENTORR_NATIVE_ANDROID') == '1':
    presets = ['android-armv7', 'android-arm64', 'android-x64']
elif system == 'Darwin':
    presets = [f'macos-{arch}']
else:
    presets = [f'{system.lower()}-{arch}']
boost = Path('/usr/include')
if system == 'Darwin':
    boost = Path(subprocess.check_output(['brew', '--prefix', 'boost'], text=True).strip()) / 'include'
elif system == 'Windows':
    boost = repo / 'boost_1_87_0'
    if not boost.exists():
        archive = repo / 'boost.tar.gz'
        urllib.request.urlretrieve('https://archives.boost.io/release/1.87.0/source/boost_1_87_0.tar.gz', archive)
        with tarfile.open(archive) as package:
            package.extractall(repo, filter='data')
for preset in presets:
    ssl_options = []
    if preset.startswith('android-'):
        import shutil
        boost = repo / 'boost-include'
        if not boost.exists():
            shutil.copytree('/usr/include/boost', boost / 'boost')
        abi = {'android-armv7':'armeabi-v7a', 'android-arm64':'arm64-v8a', 'android-x64':'x86_64'}[preset]
        subprocess.run(['bash','scripts/build_openssl_android.sh','3.4.1',abi],cwd=repo,check=True)
        ssl_root = repo / 'thirdparty/openssl-android' / abi
        ssl_options = [f'-DOPENSSL_ROOT_DIR={ssl_root}', f'-DOPENSSL_INCLUDE_DIR={ssl_root / "include"}',
            f'-DOPENSSL_SSL_LIBRARY={ssl_root / "lib/libssl.a"}', f'-DOPENSSL_CRYPTO_LIBRARY={ssl_root / "lib/libcrypto.a"}']
    elif system == 'Windows':
        subprocess.run(['pwsh','-File','scripts/build_openssl_windows.ps1','-Architecture',arch],cwd=repo,check=True)
        ssl_root = repo / 'thirdparty/openssl-windows' / arch
        ssl_options = [f'-DOPENSSL_ROOT_DIR={ssl_root}', f'-DOPENSSL_INCLUDE_DIR={ssl_root / "include"}',
            f'-DOPENSSL_SSL_LIBRARY={ssl_root / "lib/libssl.lib"}', f'-DOPENSSL_CRYPTO_LIBRARY={ssl_root / "lib/libcrypto.lib"}']
    elif system == 'Darwin':
        ssl_root = subprocess.check_output(['brew','--prefix','openssl@3'],text=True).strip()
        ssl_options = [f'-DOPENSSL_ROOT_DIR={ssl_root}']
    subprocess.run(['cmake', '--preset', preset, f'-DLTD_BINARY_LAYOUT_VERSION={version}',
        f'-DLTD_BOOST_HEADERS_ROOT={boost}', '-DCMAKE_C_COMPILER_LAUNCHER=',
        '-DCMAKE_CXX_COMPILER_LAUNCHER=', *ssl_options], cwd=repo, check=True)
    subprocess.run(['cmake', '--build', '--preset', preset, '--parallel', '3'], cwd=repo, check=True)
