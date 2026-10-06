"""Hidden macOS video playback across three real Flutter hot restarts.

Run from the repository root: python3 tool/player/hot_restart_smoke.py
Requires the codec lab's bbb_h264.mp4 fixture. No browser or UI interaction.
"""
import functools
import argparse
import http.server
import queue
import subprocess
import threading
from pathlib import Path

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--shutdown', action='store_true',
                    help='Check application shutdown during active playback')
args = parser.parse_args()
fixture = root / 'tool/codec_lab/assets/media/bbb_h264.mp4'
if not fixture.is_file():
    raise SystemExit('Missing codec lab fixture: ' + str(fixture))
handler = functools.partial(
    http.server.SimpleHTTPRequestHandler,
    directory=str(root / 'tool/codec_lab/assets/media'),
)
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
process = subprocess.Popen(
    ['flutter', 'run', '-d', 'macos', '-t', 'tool/player_native_smoke.dart',
     '--dart-define=SMOKE_SHUTDOWN=true' if args.shutdown else
     '--dart-define=SMOKE_HOT_RESTART=true',
     f'--dart-define=SMOKE_MEDIA=http://127.0.0.1:{server.server_port}/bbb_h264.mp4'],
    cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT, text=True, bufsize=1,
)
lines = queue.Queue()


def read_output():
    for line in process.stdout:
        lines.put(line)
    lines.put(None)


threading.Thread(target=read_output, daemon=True).start()
try:
    if args.shutdown:
        ready = False
        while True:
            line = lines.get(timeout=240)
            if line is None:
                break
            print(line, end='', flush=True)
            if 'Callback invoked after it has been deleted' in line:
                raise RuntimeError('Native callback fired after shutdown')
            ready |= 'SHUTDOWN_READY' in line
        if not ready or process.wait(timeout=15) != 0:
            raise RuntimeError('Application shutdown did not complete cleanly')
        print('PASS: active video shut down cleanly.')
        raise SystemExit(0)
    for cycle in range(4):
        while True:
            line = lines.get(timeout=240 if cycle == 0 else 60)
            if line is None or 'Lost connection to device' in line:
                raise RuntimeError(f'Playback lost during restart cycle {cycle}')
            print(line, end='', flush=True)
            if 'HOT_RESTART_READY' in line:
                break
        if cycle < 3:
            process.stdin.write('R\n')
            process.stdin.flush()
    print('PASS: video decoded and progressed after all three hot restarts.')
finally:
    if process.poll() is None:
        process.stdin.write('q\n')
        process.stdin.flush()
        try:
            process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            process.terminate()
    server.shutdown()
