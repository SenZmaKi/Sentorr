#!/usr/bin/env python3
"""Summarize viewing stalls separately from startup and seek buffering."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
rows = json.load(open(root / 'validation/followup.local.json'))
summary = []
for row in rows:
    playback = row.get('playback', {})
    checks = {k: v for k, v in playback.get('checks', {}).items() if k != 'stack'}
    start, end = checks.get('sustainedStartMs'), checks.get('sustainedEndMs')
    intervals = []
    opened = None
    for event in playback.get('events', []):
        if event['event'] != 'player-buffering': continue
        if event['value']:
            if opened is None: opened = event['elapsedMs']
        elif opened is not None:
            intervals.append((opened, event['elapsedMs']))
            opened = None
    if opened is not None: intervals.append((opened, playback['wallMs']))
    stalls = []
    if start is not None and end is not None:
        stalls = [min(b, end) - max(a, start) for a, b in intervals if min(b, end) > max(a, start)]
    samples = row.get('systemSamples', [])
    cpu = None
    if len(samples) > 1:
        first, last = samples[0], samples[-1]
        cpu = 100 * (last['cpuSeconds'] - first['cpuSeconds']) / (last['elapsedSeconds'] - first['elapsedSeconds'])
    summary.append({'case': row['case'], 'passed': playback.get('passed', False), 'listedSeeders': row['candidate']['seeders'] if row.get('candidate') else None, 'checks': checks, 'viewingStalls': len(stalls) if start is not None else None, 'viewingStallMs': sum(stalls) if start is not None else None, 'longestViewingStallMs': max(stalls, default=0) if start is not None else None, 'meanCpuPercent': round(cpu, 2) if cpu is not None else None, 'peakRssMiB': round(max((s['rssKiB'] for s in samples), default=0)/1024, 2), 'peakPeers': max((s.get('peers', 0) for s in playback.get('samples', [])), default=0), 'pieceLength': playback.get('snapshot', {}).get('pieceLength')})
json.dump({'date': '2026-10-02', 'runs': summary}, open(root / 'validation/usability-summary.json', 'w'), indent=2)
for row in summary: print(row)
