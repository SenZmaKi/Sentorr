#!/usr/bin/env python3
"""Run sequential native probes; sample process CPU and RSS once per second."""
import json, pathlib, subprocess, time, urllib.parse, sys

root = pathlib.Path(__file__).resolve().parents[1]
exe = root / 'build/macos/Build/Products/Release/Sentorr Streaming Lab.app/Contents/MacOS/Sentorr Streaming Lab'
rows = []
for query in ['big buck bunny', 'sintel', 'tears of steel']:
    response = subprocess.run(['curl', '-fLsS', '--max-time', '25', 'https://apibay.org/q.php?q=' + urllib.parse.quote(query)], check=True, capture_output=True, text=True)
    rows.extend(json.loads(response.stdout))
hashes = [
    '1658902A7E0FF5838A9DEC29DC92F6CD7632EC7B', # 36 MB, zero listed seeds
    'D8CF1DCE819935BBECDF6D0745886A297AF89007', # 118 MB, five
    '43F4001DE4AB25D521C63684E2B69804193ED9D9', # 584 MB, 22
    'A83525878992BC849B538DFB3CE870AB60AF03F0', # 13 GB, one
]
if len(sys.argv) > 1:
    hashes = sys.argv[1:]
results = []
for index, info_hash in enumerate(hashes):
    row = next(r for r in rows if r['info_hash'] == info_hash)
    report = root / f'validation/audit-{info_hash[:8]}.local.json'
    report.unlink(missing_ok=True)
    magnet = 'magnet:?' + urllib.parse.urlencode({'xt': 'urn:btih:' + info_hash, 'dn': row['name']})
    for tracker in ['udp://tracker.opentrackr.org:1337/announce', 'udp://open.stealth.si:80/announce', 'udp://tracker.torrent.eu.org:451/announce', 'https://tracker.gbitt.info/announce']:
        magnet += '&tr=' + urllib.parse.quote(tracker, safe='')
    samples = []
    with open(root / f'validation/audit-{info_hash[:8]}.log', 'w') as log:
        proc = subprocess.Popen([str(exe), '--audit', '--source', magnet, '--report', str(report)], cwd=root, stdout=log, stderr=log)
        start = time.monotonic()
        while proc.poll() is None and time.monotonic() - start < 240:
            stat = subprocess.run(['ps', '-p', str(proc.pid), '-o', '%cpu=,rss='], capture_output=True, text=True).stdout.split()
            if len(stat) == 2:
                samples.append({'seconds': round(time.monotonic()-start, 2), 'cpuPercent': float(stat[0]), 'rssKiB': int(stat[1])})
            time.sleep(1)
        if proc.poll() is None:
            proc.terminate()
            try: proc.wait(timeout=10)
            except subprocess.TimeoutExpired: proc.kill(); proc.wait()
    result = {'candidate': row, 'exitCode': proc.returncode, 'systemSamples': samples}
    if report.exists(): result['playback'] = json.load(open(report))
    else: result['failure'] = 'Process exceeded 240-second cap or exited without report'
    results.append(result)
    json.dump(results, open(root / ('validation/performance-retry.local.json' if len(sys.argv) > 1 else 'validation/performance.local.json'), 'w'), indent=2)
    print(row['name'], proc.returncode, result.get('playback', {}).get('checks', {}), flush=True)
