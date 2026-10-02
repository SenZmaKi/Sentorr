#!/usr/bin/env python3
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
rows = json.load(open(root/'validation/tuning.local.json'))
extra = root/'validation/tuning-refinement.local.json'
if extra.exists(): rows += json.load(open(extra))
results = []
for row in rows:
    p = row.get('playback', {})
    checks = {k:v for k,v in p.get('checks',{}).items() if k!='stack'}
    if checks.get('volume') == 100.0 and not row['controlled']:
        checks['volumeSampledBeforePlayerOpen'] = checks.pop('volume')
    start, end = checks.get('sustainedStartMs'), checks.get('sustainedEndMs')
    intervals, opened = [], None
    for e in p.get('events',[]):
        if e['event'] != 'player-buffering': continue
        if e['value']:
            if opened is None: opened=e['elapsedMs']
        elif opened is not None:
            intervals.append((opened,e['elapsedMs'])); opened=None
    if opened is not None: intervals.append((opened,p['wallMs']))
    stalls = [min(b,end)-max(a,start) for a,b in intervals if min(b,end)>max(a,start)] if start is not None else None
    progression = checks.get('sustainedEndPositionMs',0)-checks.get('sustainedStartPositionMs',0) if start is not None else None
    result = {'case':row['case'], 'capMbps':row['capMbps'], 'readySeconds':row['readySeconds'], 'passed':p.get('passed',False), 'checks':checks, 'viewingStalls':len(stalls) if stalls is not None else None, 'viewingStallMs':sum(stalls) if stalls is not None else None, 'viewingProgressMs':progression, 'viewingLostTimeMs': max(0, (end-start)-progression) if start is not None else None, 'middleSeekComparable': not row['controlled'] or row['capMbps']==5 or 'seek-0.5FromPositionMs' in checks, 'snapshot':{k:v for k,v in p.get('snapshot',{}).items() if k!='pieceSamples'}, 'profile':p.get('profile')}
    results.append(result)
    print(result)
json.dump({'date':'2026-10-02','cases':results},open(root/'validation/tuning-summary.json','w'),indent=2)
