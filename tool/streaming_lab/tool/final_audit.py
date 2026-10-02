#!/usr/bin/env python3
"""Controlled startup-policy comparisons, then capped public swarm checks."""
import json
import os
from pathlib import Path
import subprocess
import urllib.parse
root = Path(__file__).resolve().parents[1]
exe = root/'build/macos/Build/Products/Release/Sentorr Streaming Lab.app/Contents/MacOS/Sentorr Streaming Lab'
fixture = str(root/'fixtures/network-tail.mp4')
cases = [
    ('timeout1',fixture,True,10,1,False,False),
    ('timeout5',fixture,True,10,5,False,False),
    ('timeout60',fixture,True,10,60,False,False),
    ('narrow60',fixture,True,10,60,True,False),
    ('bootstrap10',fixture,True,10,60,True,True),
    ('bootstrap40',fixture,True,40,60,True,True),
    ('baseline40',fixture,True,40,60,False,False),
    ('narrow40',fixture,True,40,60,True,False),
]
for name, value in [('sintel','43F4001DE4AB25D521C63684E2B69804193ED9D9'),('sintel-repeat','43F4001DE4AB25D521C63684E2B69804193ED9D9'),('webm','02767050E0BE2FD4DB9A2AD6C12416AC806ED6ED')]:
    source = 'magnet:?xt=urn:btih:'+value
    for tracker in ['udp://tracker.opentrackr.org:1337/announce','udp://open.stealth.si:80/announce','udp://tracker.torrent.eu.org:451/announce','https://tracker.gbitt.info/announce']:
        source += '&tr='+urllib.parse.quote(tracker,safe='')
    cases.append((name,source,False,40,60,True,True))
selected = os.environ.get('STREAMING_FINAL_CASES','').split(',')
if selected != ['']: cases=[c for c in cases if c[0] in selected]
transport=os.environ.get('STREAMING_FORCE_TCP','1')
results=[]
for name,source,controlled,cap,timeout,narrow,bootstrap in cases:
    if transport=='1': name='tcp-'+name
    report=root/f'validation/final-{name}.local.json'
    report.unlink(missing_ok=True)
    env={**os.environ,'STREAMING_DOWNLOAD_MBPS':str(cap),'STREAMING_NETWORK_TIMEOUT':str(timeout),'STREAMING_NARROW_URGENT':str(int(narrow)),'STREAMING_BOOTSTRAP':str(int(bootstrap)),'STREAMING_BUFFER_SECONDS':'60','STREAMING_RESUME_SECONDS':'10','STREAMING_SUSTAINED_SECONDS':'60'}
    if controlled:
        env.update(STREAMING_CONTROLLED_MBPS=str(cap),STREAMING_CONTROLLED_PIECE_BYTES=str(8*1024*1024))
    args=[str(exe),'--audit','--source',source,'--report',str(report)]
    if controlled: args+=['--controlled']
    with open(root/f'validation/final-{name}.log','w') as log:
        process=subprocess.Popen(args,cwd=root,env=env,stdout=log,stderr=log)
        try: process.wait(timeout=360)
        except subprocess.TimeoutExpired:
            process.terminate()
            try: process.wait(timeout=10)
            except subprocess.TimeoutExpired: process.kill();process.wait()
    result={'case':name,'controlled':controlled,'capMbps':cap,'networkTimeoutSeconds':timeout,'narrow':narrow,'bootstrap':bootstrap,'exitCode':process.returncode,'forceTcp':transport=='1'}
    if report.exists():result['playback']=json.load(open(report))
    else:result['failure']='No report: process timeout or crash'
    results.append(result)
    json.dump(results,open(root/('validation/'+os.environ.get('STREAMING_FINAL_AGGREGATE', 'final-tcp.local.json' if transport=='1' else 'final-audit.local.json')),'w'),indent=2)
    print(name,result.get('playback',{}).get('checks',result),flush=True)
