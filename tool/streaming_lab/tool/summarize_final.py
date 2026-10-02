#!/usr/bin/env python3
"""Produce shareable results without raw source URIs, paths or peer addresses."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
rows = []
for name in ['final-audit.local.json', 'final-tcp.local.json', 'final-refinement.local.json', 'final-default.local.json']:
    path = root/'validation'/name
    if path.exists(): rows += json.loads(path.read_text())
results = []
for row in rows:
    playback = row.get('playback', {})
    checks = {k:v for k,v in playback.get('checks', {}).items() if k != 'stack'}
    events = playback.get('events', [])
    metadata = next((e['elapsedMs'] for e in events if e['event']=='metadata-ready'), None)
    start, end = checks.get('sustainedStartMs'), checks.get('sustainedEndMs')
    progress = checks.get('sustainedEndPositionMs',0)-checks.get('sustainedStartPositionMs',0) if start is not None else None
    sustained = [s for s in playback.get('samples',[]) if s['phase']=='sustained']
    first = checks.get('firstPlaybackMs')
    requests = [e for e in events if e['event']=='request' and (first is None or e['elapsedMs'] <= first)]
    results.append({
        **{k:v for k,v in row.items() if k!='playback'},
        'forceTcp':row.get('forceTcp',False),
        'passed':playback.get('passed',False),
        'checks':checks,
        'metadataEventMs':metadata,
        'bootstrapMs':next((e['elapsedBootstrapMs'] for e in events if e['event']=='bootstrap-ready'),None),
        'viewingProgressMs':progress,
        'viewingLostTimeMs':max(0,end-start-progress) if start is not None else None,
        'waitingSamplesDuringViewing':sum(bool(s.get('cacheWaiting') or s.get('buffering')) for s in sustained),
        'viewingSampleCount':len(sustained),
        'startupHttpRequests':len(requests),
        'pieceLength':playback.get('snapshot',{}).get('pieceLength'),
    })
output={'date':'2026-10-02','method':'Sequential fresh-cache macOS release playback; viewing sampled every second; HTTP range completion still requires full verified torrent pieces. Public runs are observational, not randomized matched swarms.','cases':results}
(root/'validation/final-summary.json').write_text(json.dumps(output,indent=2)+'\n')
for r in results:
    c=r['checks'];print(r['case'],r['passed'],'first',c.get('firstPlaybackMs'),'view',r['viewingProgressMs'],'seeks',[c.get(f'seek-{f}Ms') for f in [0.5,0.9,0.05]],'rapid',c.get('rapidSeeksMs'),'requests',r['startupHttpRequests'])
