#!/usr/bin/env python3
"""Sequential idle baseline, repeated public swarms, longer discovery budget."""
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.parse

root = Path(__file__).resolve().parents[1]
exe = root / 'build/macos/Build/Products/Release/Sentorr Streaming Lab.app/Contents/MacOS/Sentorr Streaming Lab'
rows = []
for query in ['sintel', 'tears of steel']:
    response = subprocess.run(['curl', '-fLsS', '--max-time', '25', 'https://apibay.org/q.php?q=' + urllib.parse.quote(query)], check=True, capture_output=True, text=True)
    rows.extend(json.loads(response.stdout))
cases = []
for repeat in range(3):
    cases.extend([(f'sintel-{repeat}', '43F4001DE4AB25D521C63684E2B69804193ED9D9'), (f'webm-{repeat}', '02767050E0BE2FD4DB9A2AD6C12416AC806ED6ED')])

results = []
for name, info_hash in cases:
    report = root / f'validation/followup-{name}.local.json'
    report.unlink(missing_ok=True)
    row = next((r for r in rows if r['info_hash'] == info_hash), None)
    args = [str(exe), '--audit', '--report', str(report)]
    if info_hash:
        if row is None:
            results.append({'case': name, 'failure': 'Candidate missing from current search'})
            continue
        magnet = 'magnet:?' + urllib.parse.urlencode({'xt': 'urn:btih:' + info_hash, 'dn': row['name']})
        for tracker in ['udp://tracker.opentrackr.org:1337/announce', 'udp://open.stealth.si:80/announce', 'udp://tracker.torrent.eu.org:451/announce', 'https://tracker.gbitt.info/announce']:
            magnet += '&tr=' + urllib.parse.quote(tracker, safe='')
        args += ['--source', magnet]
    else:
        args += ['--idle']
    samples = []
    with open(root / f'validation/followup-{name}.log', 'w') as log:
        proc = subprocess.Popen(args, cwd=root, env={**os.environ, 'STREAMING_METADATA_SECONDS': '60', 'STREAMING_SUSTAINED_SECONDS': '120'}, stdout=log, stderr=log)
        start = time.monotonic()
        while proc.poll() is None and time.monotonic() - start < 360:
            stat = subprocess.run(['ps', '-p', str(proc.pid), '-o', 'time=,rss='], capture_output=True, text=True).stdout.split()
            if len(stat) == 2:
                minutes, seconds = stat[0].split(':')
                samples.append({'elapsedSeconds': time.monotonic() - start, 'cpuSeconds': int(minutes) * 60 + float(seconds), 'rssKiB': int(stat[1])})
            time.sleep(1)
        capped = proc.poll() is None
        if capped:
            proc.terminate()
            try: proc.wait(timeout=10)
            except subprocess.TimeoutExpired: proc.kill(); proc.wait()
    result = {'case': name, 'candidate': row, 'exitCode': proc.returncode, 'capped': capped, 'systemSamples': samples}
    if report.exists(): result['playback'] = json.load(open(report))
    results.append(result)
    json.dump(results, open(root / 'validation/followup.local.json', 'w'), indent=2)
    print(name, result.get('playback', {}).get('checks', {}), flush=True)
