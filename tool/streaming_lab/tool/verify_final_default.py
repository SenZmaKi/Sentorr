#!/usr/bin/env python3
"""Check actual lab defaults, without forcing the experimental policy knobs."""
import json
import os
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
exe = root/'build/macos/Build/Products/Release/Sentorr Streaming Lab.app/Contents/MacOS/Sentorr Streaming Lab'
report = root/'validation/final-default-playback.local.json'
report.unlink(missing_ok=True)
env = dict(os.environ)
for name in ['STREAMING_FORCE_TCP','STREAMING_BOOTSTRAP','STREAMING_NARROW_URGENT','STREAMING_NETWORK_TIMEOUT','STREAMING_BUFFER_SECONDS','STREAMING_RESUME_SECONDS','STREAMING_READAHEAD_MIB']:
    env.pop(name,None)
env.update(STREAMING_DOWNLOAD_MBPS='40',STREAMING_CONTROLLED_MBPS='40',STREAMING_CONTROLLED_PIECE_BYTES='8388608',STREAMING_SUSTAINED_SECONDS='60')
with open(root/'validation/final-default.log','w') as log:
    result = subprocess.run([str(exe),'--audit','--controlled','--source',str(root/'fixtures/network-tail.mp4'),'--report',str(report)],cwd=root,env=env,stdout=log,stderr=log,timeout=240)
playback = json.loads(report.read_text())
policy = next(e for e in playback['events'] if e['event']=='playback-profile')
assert policy['tcpOnly'] and policy['bootstrap'] and policy['narrowUrgent'], policy
assert int(policy['networkTimeoutSeconds'])==60 and policy['resumeSeconds']==10, policy
row={'case':'actual-default40','controlled':True,'capMbps':40,'networkTimeoutSeconds':60,'narrow':True,'bootstrap':True,'forceTcp':True,'exitCode':result.returncode,'playback':playback}
(root/'validation/final-default.local.json').write_text(json.dumps([row],indent=2)+'\n')
print(playback['checks'],flush=True)
raise SystemExit(result.returncode)
