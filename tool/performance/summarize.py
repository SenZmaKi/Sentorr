#!/usr/bin/env python3
"""Summarize interval CPU (100% = one core) and resident memory by phase."""
import collections, json, pathlib, statistics, sys
root = pathlib.Path(sys.argv[1])
rows = [json.loads(line) for line in (root / 'os.jsonl').read_text().splitlines()]
groups = collections.defaultdict(list)
for before, after in zip(rows, rows[1:]):
    if before['phase'] == after['phase']:
        seconds = after['monotonic'] - before['monotonic']
        groups[after['phase']].append((seconds, max(0, after['cpuSeconds'] - before['cpuSeconds']), after['rssKiB'] / 1024))
summary = {}
for phase, samples in groups.items():
    seconds = sum(s[0] for s in samples)
    summary[phase] = {'seconds': round(seconds, 1),
        'meanCpuPercent': round(100 * sum(s[1] for s in samples) / seconds, 2),
        'peakOneSecondCpuPercent': round(max(100 * s[1] / s[0] for s in samples), 2),
        'medianRssMiB': round(statistics.median(s[2] for s in samples), 1),
        'peakRssMiB': round(max(s[2] for s in samples), 1),
        'endRssMiB': round(samples[-1][2], 1)}
(root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
