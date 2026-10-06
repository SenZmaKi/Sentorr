"""Hidden AppKit tray checks across hot restarts, then native termination."""
import queue
import subprocess
import threading
import time


def run(quit_mode=False):
    command = ['flutter', 'run', '-d', 'macos', '-t', 'tool/tray_native_smoke.dart']
    if quit_mode:
        command.append('--dart-define=SMOKE_QUIT=true')
    process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, bufsize=1)
    lines = queue.Queue()
    def read():
        for line in process.stdout:
            lines.put(line)
        lines.put(None)
    threading.Thread(target=read, daemon=True).start()
    try:
        for cycle in range(1 if quit_mode else 4):
            while True:
                line = lines.get(timeout=240)
                if line is None or 'Lost connection to device' in line:
                    raise RuntimeError('App exited before tray was checked')
                print(line, end='', flush=True)
                if 'TRAY_READY' in line:
                    break
            if not quit_mode and cycle < 3:
                process.stdin.write('R\n')
                process.stdin.flush()
        if quit_mode:
            start = time.monotonic()
            if process.wait(timeout=20) != 0:
                raise RuntimeError('Native quit failed')
            print(f'PASS: native quit completed in {time.monotonic() - start:.2f}s')
        else:
            print('PASS: native tray bounds and Dart click handling passed across three hot restarts')
    finally:
        if process.poll() is None:
            process.stdin.write('q\n')
            process.stdin.flush()
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.terminate()

run()
run(quit_mode=True)
