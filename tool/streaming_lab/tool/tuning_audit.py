#!/usr/bin/env python3
"""Bounded bandwidth matrix plus real-swarm smoothing comparisons."""
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.parse
root = Path(__file__).resolve().parents[1]
exe = root / 'build/macos/Build/Products/Release/Sentorr Streaming Lab.app/Contents/MacOS/Sentorr Streaming Lab'
trackers = ['udp://tracker.opentrackr.org:1337/announce', 'udp://open.stealth.si:80/announce', 'udp://tracker.torrent.eu.org:451/announce', 'https://tracker.gbitt.info/announce']
cases = [(f'controlled-{cap}', str(root/'fixtures/network-8mbps.mp4'), True, cap, 10) for cap in [5, 10, 20, 40]]
for name, hash_value, ready in [('webm-10', '02767050E0BE2FD4DB9A2AD6C12416AC806ED6ED', 10), ('webm-20', '02767050E0BE2FD4DB9A2AD6C12416AC806ED6ED', 20), ('sintel-10', '43F4001DE4AB25D521C63684E2B69804193ED9D9', 10)]:
    magnet = 'magnet:?xt=urn:btih:' + hash_value
    for tracker in trackers: magnet += '&tr=' + urllib.parse.quote(tracker, safe='')
    cases.append((name, magnet, False, 40, ready))
cases += [('controlled-40-ready5', str(root/'fixtures/network-8mbps.mp4'), True, 40, 5), ('controlled-10-ready5', str(root/'fixtures/network-8mbps.mp4'), True, 10, 5)]
magnet = 'magnet:?xt=urn:btih:43F4001DE4AB25D521C63684E2B69804193ED9D9'
for tracker in trackers: magnet += '&tr=' + urllib.parse.quote(tracker, safe='')
cases.append(('sintel-5', magnet, False, 40, 5))
selected = os.environ.get('STREAMING_TUNING_CASES', '').split(',')
if selected != ['']: cases = [case for case in cases if case[0] in selected]
results = []
for name, source, controlled, cap, ready in cases:
    report = root/f'validation/tuning-{name}.local.json'
    report.unlink(missing_ok=True)
    env = {**os.environ, 'STREAMING_DOWNLOAD_MBPS': str(cap), 'STREAMING_BUFFER_SECONDS': '60', 'STREAMING_RESUME_SECONDS': str(ready), 'STREAMING_SUSTAINED_SECONDS': os.environ.get('STREAMING_SUSTAINED_SECONDS', '90')}
    if controlled: env['STREAMING_CONTROLLED_MBPS'] = str(cap)
    args = [str(exe), '--audit', '--source', source, '--report', str(report)]
    if controlled: args += ['--controlled']
    with open(root/f'validation/tuning-{name}.log','w') as log:
        process = subprocess.Popen(args, cwd=root, env=env, stdout=log, stderr=log)
        try: process.wait(timeout=420)
        except subprocess.TimeoutExpired:
            process.terminate()
            try: process.wait(timeout=10)
            except subprocess.TimeoutExpired: process.kill(); process.wait()
    result = {'case': name, 'capMbps': cap, 'readySeconds': ready, 'controlled': controlled, 'exitCode': process.returncode}
    if report.exists(): result['playback'] = json.load(open(report))
    else: result['failure'] = 'No report (process cap or crash)'
    results.append(result)
    json.dump(results, open(root/('validation/tuning-refinement.local.json' if selected != [''] else 'validation/tuning.local.json'),'w'), indent=2)
    print(name, result.get('playback',{}).get('checks',result),flush=True)
