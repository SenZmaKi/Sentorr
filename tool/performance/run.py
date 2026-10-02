#!/usr/bin/env python3
"""Run the separately built hidden profiling app; preserve raw OS samples."""
import argparse, json, os, pathlib, re, subprocess, threading, time, urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('--root', required=True)
parser.add_argument('--app', default='build/macos/Build/Products/Profile/Sentorr.app/Contents/MacOS/Sentorr')
args = parser.parse_args()
root = pathlib.Path(args.root)
root.mkdir(parents=True, exist_ok=True)
if (root / 'data').exists():
    raise SystemExit('Use a fresh root: existing caches/downloads change the workload.')
if not (root / 'seed.json').exists():
    raise SystemExit('Start seed.dart with this root/seed.json first.')
(root / 'host.txt').write_text(subprocess.run(['sw_vers'], capture_output=True, text=True).stdout +
    subprocess.run(['sysctl', 'machdep.cpu.brand_string', 'hw.memsize'], capture_output=True, text=True).stdout +
    subprocess.run(['vm_stat'], capture_output=True, text=True).stdout)
env = dict(os.environ, SENTORR_AUDIT_ROOT=str(root.resolve()))
proc = subprocess.Popen([str(pathlib.Path(args.app).resolve())], env=env,
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
state = {'phase': 'startup', 'service': None}

def read():
    with (root / 'app.log').open('w') as log:
        for line in proc.stdout:
            log.write(line)
            log.flush()
            if 'The Dart VM service is listening on ' in line:
                state['service'] = re.search(r'listening on (http://\S+)', line).group(1)
            if 'AUDIT ' in line:
                event = json.loads(line.split('AUDIT ', 1)[1])
                if event.get('event') == 'complete':
                    state['phase'] = 'shutdown'
                if 'phase' in event:
                    state['phase'] = event['phase']
                if event.get('event'):
                    print(line.strip(), flush=True)
thread = threading.Thread(target=read)
thread.start()
started = time.monotonic()
sampled = set()
last_heap = 0
with (root / 'os.jsonl').open('w') as log:
    while proc.poll() is None:
        start = time.monotonic()
        if start - started > 900:
            proc.kill()
            raise SystemExit('Audit exceeded 15 minutes; inspect app.log.')
        ps = subprocess.run(['ps', '-p', str(proc.pid), '-o', 'time=', '-o', 'rss='],
                            capture_output=True, text=True).stdout.strip()
        if ps:
            cpu_time, rss = ps.split()
            parts = cpu_time.split(':')
            seconds = float(parts[-1]) + 60 * float(parts[-2])
            if len(parts) == 3:
                seconds += 3600 * float(parts[0])
            log.write(json.dumps({'monotonic': start, 'phase': state['phase'],
                                  'cpuSeconds': seconds, 'rssKiB': int(rss)}) + '\n')
            log.flush()
        phase = state['phase']
        if state['service'] and start - last_heap >= 5:
            last_heap = start
            try:
                uri = state['service']
                vm = json.load(urllib.request.urlopen(uri + 'getVM', timeout=2))['result']
                isolate = vm['isolates'][0]['id']
                heap = json.load(urllib.request.urlopen(uri + 'getMemoryUsage?isolateId=' + isolate, timeout=2))['result']
                with (root / 'heap.jsonl').open('a') as out:
                    out.write(json.dumps({'phase': phase, 'monotonic': start, 'memory': heap}) + '\n')
            except Exception as error:
                print('Heap sample unavailable:', type(error).__name__, flush=True)
        if phase in {'home_idle', 'download', 'stream_playing', 'post_close', 'home_return', 'home_tickers_disabled', 'home_tickers_resumed', 'blank_ui'} and phase not in sampled:
            sampled.add(phase)
            subprocess.Popen(['sample', str(proc.pid), '3', '-file', str(root / f'{phase}.sample.txt')],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.Popen(['vmmap', '-summary', str(proc.pid)], stdout=(root / f'{phase}.vmmap.txt').open('w'),
                             stderr=subprocess.DEVNULL)
        time.sleep(max(0, 1 - (time.monotonic() - start)))
thread.join()
raise SystemExit(proc.returncode)
