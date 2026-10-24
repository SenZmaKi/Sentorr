"""macOS AOT comparison of HEAD vs working-tree torrent HTTP implementations.

No Flutter, mpv, thumbnail extraction, Internet peers, or synthetic native reader.
Each measured workload runs in a fresh process against a preverified warm file.
"""
import ctypes
import hashlib
import json
import pathlib
import shutil
import statistics
import subprocess
import sys
import threading
import time

REPO = pathlib.Path(__file__).resolve().parents[2]
ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '/tmp/sentorr-stream-io-audit')
OUT = REPO / 'tool/stream_io_audit/results.json'
SIZES = [256 * 1024, 1024 * 1024, 16 * 1024 * 1024, 128 * 1024 * 1024]


def snapshot():
    ROOT.mkdir(exist_ok=True, parents=True)
    package = REPO / 'packages/torrent_stream'
    for variant in ['old', 'new']:
        dest = ROOT / variant
        if dest.exists():
            shutil.rmtree(dest)
        dest.mkdir()
        if variant == 'old':
            paths = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', 'HEAD',
                                             'packages/torrent_stream/lib'], cwd=REPO, text=True).splitlines()
            for path in paths:
                target = dest / pathlib.Path(path).relative_to('packages/torrent_stream')
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(subprocess.check_output(['git', 'show', f'HEAD:{path}'], cwd=REPO))
        else:
            shutil.copytree(package / 'lib', dest / 'lib')
        for name in ['pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml']:
            if (package / name).exists():
                shutil.copy2(package / name, dest / name)
        (dest / 'tool').mkdir()
        shutil.copy2(REPO / 'tool/stream_io_audit/worker.dart', dest / 'tool/worker.dart')
        subprocess.run(['dart', 'pub', 'get', '--offline'], cwd=dest, check=True, stdout=subprocess.DEVNULL)
        subprocess.run(['dart', 'build', 'cli', '-t', 'tool/worker.dart', '-o', 'aot'], cwd=dest, check=True)


def executable(variant):
    return ROOT / variant / 'aot/bundle/bin/worker'


def fixture():
    dest = ROOT / 'fixture'
    dest.mkdir(exist_ok=True)
    file = dest / 'video.bin'
    size = 256 * 1024 * 1024
    if not file.exists() or file.stat().st_size != size:
        block = bytes(range(251)) * 4096
        with file.open('wb') as output:
            remaining = size
            while remaining:
                count = min(remaining, len(block))
                output.write(block[:count])
                remaining -= count
    for size in SIZES:
        subprocess.run([str(executable('new')), str(dest), str(size), 'prepare'], check=True)
    return dest


# External sampling continues while native FFI blocks the Dart event loop.
LIBPROC = ctypes.CDLL('/usr/lib/libproc.dylib')
LIBPROC.proc_pidinfo.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_uint64,
                                ctypes.c_void_p, ctypes.c_int]
LIBPROC.proc_pidinfo.restype = ctypes.c_int


def run(variant, size, scenario, repeat, fixture_dir):
    process = subprocess.Popen([str(executable(variant)), str(fixture_dir), str(size), scenario],
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, text=True)
    peak = [0]
    stopped = threading.Event()

    def sample():
        info = ctypes.create_string_buffer(256)
        while not stopped.is_set():
            # Darwin PROC_PIDTASKINFO=4, resident size is the second uint64.
            count = LIBPROC.proc_pidinfo(process.pid, 4, 0, info, len(info))
            if count >= 16:
                peak[0] = max(peak[0], ctypes.c_uint64.from_buffer(info, 8).value)
            stopped.wait(.005)

    result = None
    sampler = None
    for line in process.stdout:
        event = json.loads(line)
        if event['event'] == 'ready':
            sampler = threading.Thread(target=sample)
            sampler.start()
            process.stdin.write('go\n')
            process.stdin.flush()
        elif event['event'] == 'result':
            stopped.set()
            if sampler:
                sampler.join()
            result = event
    error = process.stderr.read()
    code = process.wait()
    stopped.set()
    if sampler:
        sampler.join()
    if code or result is None:
        raise RuntimeError(f'{variant}/{size}/{scenario}: exit {code}: {error}')
    result.update(variant=variant, repeat=repeat, externalRssPeak=peak[0])
    result['rssPeak'] = max(result['rssPeakSampled'], peak[0])
    print(f"{variant:3} {size // 1024:6} KiB {scenario:10} repeat {repeat}: "
          f"{result['elapsedMs']:.1f} ms, CPU {result['cpuMs']:.1f} ms, "
          f"RSS {result['rssPeak'] / 2**20:.1f} MiB", flush=True)
    return result


def main():
    if sys.platform != 'darwin':
        raise SystemExit('This audit runner uses macOS resident-memory sampling.')
    # --reuse uses existing frozen builds, useful after an interrupted audit.
    if '--reuse' not in sys.argv:
        snapshot()
    fixture_dir = fixture()
    libraries = {}
    for variant in ['old', 'new']:
        lib = next((ROOT / variant / 'aot/bundle/lib').glob('*'))
        libraries[variant] = hashlib.sha256(lib.read_bytes()).hexdigest()
    if libraries['old'] != libraries['new']:
        raise RuntimeError('Native libraries differ between benchmark builds')
    source_hashes = {}
    for variant in ['old', 'new']:
        digest = hashlib.sha256()
        for file in sorted((ROOT / variant / 'lib').rglob('*.dart')):
            digest.update(str(file.relative_to(ROOT / variant)).encode())
            digest.update(file.read_bytes())
        source_hashes[variant] = digest.hexdigest()
    output = {'baselineCommit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO, text=True).strip(),
              'platform': subprocess.check_output(['uname', '-a'], text=True).strip(),
              'dart': subprocess.check_output(['dart', '--version'], text=True).strip(),
              'workerSha256': hashlib.sha256((ROOT / 'new/tool/worker.dart').read_bytes()).hexdigest(),
              'workerSource': (ROOT / 'new/tool/worker.dart').read_text(),
              'sourceSha256': source_hashes, 'nativeLibrarySha256': libraries,
              'fixtureBytes': 256 * 1024 * 1024, 'runs': []}
    for size in SIZES:
        for scenario in ['sequential', 'seeks']:
            for repeat in range(3):
                # Alternate ordering to reduce cache/thermal/order bias.
                order = ['old', 'new'] if repeat % 2 == 0 else ['new', 'old']
                for variant in order:
                    output['runs'].append(run(variant, size, scenario, repeat, fixture_dir))
                    OUT.write_text(json.dumps(output, indent=2) + '\n')
    summary = []
    for size in SIZES:
        for scenario in ['sequential', 'seeks']:
            record = {'pieceBytes': size, 'scenario': scenario}
            for variant in ['old', 'new']:
                runs = [r for r in output['runs'] if r['variant'] == variant
                        and r['pieceBytes'] == size and r['scenario'] == scenario]
                record[variant] = {key: statistics.median(r[key] for r in runs)
                                   for key in ['elapsedMs', 'cpuMs', 'rssStart', 'rssPeak', 'throughputMiBs']}
                if scenario == 'seeks':
                    record[variant]['seekP95Ms'] = statistics.median(r['seekP95Ms'] for r in runs)
            record['speedup'] = record['old']['elapsedMs'] / record['new']['elapsedMs']
            summary.append(record)
    output['summary'] = summary
    OUT.write_text(json.dumps(output, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
