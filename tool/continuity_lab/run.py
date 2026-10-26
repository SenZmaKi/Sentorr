#!/usr/bin/env python3
"""Build once and launch two isolated Sentorr processes on this Mac."""
import argparse
import json
import os
import shutil
import signal
from pathlib import Path
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('--media', type=Path, help='Local video at least 15 seconds long; defaults to a looped bundled sample')
parser.add_argument('--smoke', action='store_true', help='Hidden automated native playback check')
parser.add_argument('--partial', action='store_true', help='Use a real unfinished loopback torrent on the host')
parser.add_argument('--sidecar', action='store_true', help='Transfer a selected external subtitle file')
parser.add_argument('--outage', choices=['brief', 'permanent'], help='Interrupt the host after handoff; requires --smoke --partial')
args = parser.parse_args()
if args.outage and not (args.smoke and args.partial):
    parser.error('--outage requires --smoke --partial')
repo = Path(__file__).resolve().parents[2]
media = args.media.resolve(strict=True) if args.media else None
subprocess.run(['flutter', 'build', 'macos', '--debug', '-t',
                    'tool/continuity_lab/main.dart'], cwd=repo, check=True)
apps = list((repo / 'build/macos/Build/Products/Debug').glob('*.app'))
app = next(p for p in apps if (p / 'Contents/MacOS/Sentorr').exists())
executable = app / 'Contents/MacOS/Sentorr'
# Use the app sandbox's temp folder so both native processes can access the run.
base = Path.home() / 'Library/Containers/com.sentorr.sentorr/Data/tmp'
base.mkdir(parents=True, exist_ok=True)
root = Path(tempfile.mkdtemp(prefix='continuity-lab-', dir=base))
root.chmod(0o700)
fixture = root / f'fixture{media.suffix if media else ".mp4"}'
if media:
    shutil.copy2(media, fixture)
else:
    ffmpeg = shutil.which('ffmpeg')
    if not ffmpeg:
        parser.error('Install ffmpeg or provide --media /path/to/video.mp4')
    subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-stream_loop', '59' if args.partial else '5',
                    '-i', str(repo / 'tool/codec_lab/assets/media/bbb_h264.mp4'),
                    '-t', '600' if args.partial else '60', '-c', 'copy', str(fixture)], check=True)
print(f'Lab data and logs: {root}', flush=True)
processes = []
try:
    for role in ['MacBook', 'Phone']:
        env = dict(os.environ, SENTORR_LAB_ROLE=role, SENTORR_LAB_OUTAGE=args.outage or '', SENTORR_LAB_ROOT=str(root),
                   SENTORR_LAB_MEDIA=str(fixture), SENTORR_LAB_SIDECAR='1' if args.sidecar else '0', SENTORR_LAB_PARTIAL='1' if args.partial else '0', SENTORR_LAB_SMOKE='1' if args.smoke else '0')
        log = (root / f'{role}.log').open('w')
        processes.append(subprocess.Popen([str(executable)], env=env, stdout=log, stderr=subprocess.STDOUT))
        log.close()
    if args.smoke:
        deadline = time.monotonic() + 180
        interrupted = False
        resume_at = None
        while any(p.poll() is None for p in processes) and time.monotonic() < deadline:
            if args.outage and not interrupted and (root / 'outage-ready').exists():
                interrupted = True
                if args.outage == 'brief':
                    processes[0].send_signal(signal.SIGSTOP)
                    resume_at = time.monotonic() + 3
                else:
                    processes[0].kill()
                (root / 'outage-started').write_text('started')
            if resume_at is not None and time.monotonic() >= resume_at:
                processes[0].send_signal(signal.SIGCONT)
                resume_at = None
            time.sleep(0.25)
        results = {}
        for role in ['MacBook', 'Phone']:
            output = root / f'{role}-result.json'
            results[role] = json.loads(output.read_text()) if output.exists() else {'ok': False, 'error': 'No result; inspect log'}
        print(json.dumps(results, indent=2))
        if not all(v['ok'] for v in results.values()) or any(p.poll() != 0 and not (i == 0 and args.outage == 'permanent') for i, p in enumerate(processes)):
            raise SystemExit(1)
    else:
        print('Two windows are paired. On Lab Phone, tap Continue here. Ctrl-C closes both.', flush=True)
        for process in processes:
            process.wait()
except KeyboardInterrupt:
    pass
finally:
    for process in processes:
        if process.poll() is None:
            if args.outage == 'brief':
                process.send_signal(signal.SIGCONT)
            process.terminate()
    for process in processes:
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
