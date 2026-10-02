# Streaming usability audit

Follow-up to PERFORMANCE.md, measured on 2026-10-02 on the same macOS arm64
host. This audit asks whether ordinary viewing and scrubbing are usable.
It uses three fresh-cache runs per real Pirate Bay torrent, two minutes of
continuous playback per run, then middle, late, backward and rapid seeks.
The measured results table is appended below after the sequential matrix.

## What the measurements establish

- Start time includes metadata acquisition and requires more than one second
  of progressing player position. It is slightly longer than first-frame time.
- Seek time includes issuing the command and waiting for at least 0.5 seconds
  of playback beyond the target. Position must also remain within 15 seconds
  of the intended target. Middle/late/backward targets are 50%, 90% and 5%.
- Rapid seeking issues 20%, 70%, then 30% targets consecutively; its total time
  ends when playback advances beyond the final target. This tests command
  succession, not a simulated mouse-drag gesture.
- Viewing stalls are buffering intervals intersecting the two-minute viewing
  window. Startup and deliberate seek buffering are excluded. Buffering event
  durations and video position progression are both retained in the evidence.
- Pause drift is measured over two seconds; playback progression after resume
  must pass a further 0.5 seconds. Functional checks passing do not mean a
  comfortable viewing experience.

Each run has a new process and temporary torrent download directory; the
player has its normal 2 MiB buffer and the bridge its 8 MiB piece cache.
Public peer capacity and connection count can change between runs. Both
candidates list multiple trackers and allow normal libtorrent discovery.
The tests remain sequential so they do not compete with one another.

## Limits

These are native release playback measurements, without browser inspection.
They confirm reported decoded dimensions, player progression and buffering,
not a human visual/audio quality review or dropped-frame assessment. Two
short films on one host/network do not establish universal codec or network
compatibility. Three samples support repeatability observations, not p95/p99
claims. No engine tuning was applied between the samples.

Use `python3 tool/followup_audit.py` after `flutter build macos --release`, then
`python3 tool/summarize_usability.py`. The runner fetches the candidates' current
Pirate Bay listings, uses a 60-second metadata budget and 360-second process
cap, and writes ignored raw reports with system and engine samples. The
summary is saved as `validation/usability-summary.json`. CPU is computed from
process CPU time deltas divided by wall time; it includes Flutter rendering,
libtorrent and playback. Memory is process resident memory sampled once per
second. A cap or timeout is a failed run, never a reused earlier report.

The audit also adds snapshots during metadata acquisition and records piece
length, without changing the piece scheduling algorithm. Analysis and all
seven HTTP transport tests passed; the release executable was rebuilt.

## Measured results and verdict

**Conditionally usable for ordinary watching on the healthier swarm; not yet
reliably usable across the tested swarms, and not responsive for seeking.**

| Run | Start including metadata | Stalls in 120 s viewing | Total viewing stall time | Middle seek | Late seek | Backward seek | Rapid seeks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Sintel 1 | 16.40 s | 1 | 0.30 s | 8.96 s | 18.65 s | 0.61 s | 11.91 s |
| Sintel 2 | 21.23 s | 1 | 0.21 s | 6.62 s | 20.13 s | 0.61 s | 17.23 s |
| Sintel 3 | 20.33 s | 1 | 0.23 s | 9.32 s | 23.92 s | 0.61 s | 19.18 s |
| WebM 1 | 9.72 s | 23 | 64.55 s | 12.52 s | 18.95 s | 1.02 s | 20.05 s |
| WebM 2 | 9.97 s | 16 | 31.98 s | 8.95 s | 12.37 s | 1.02 s | 10.18 s |
| WebM 3 | Metadata timeout, 60 s | — | — | — | — | — | — |

All five completed playback runs paused without position drift and resumed.
The six attempts delivered ten minutes of measured ordinary viewing, plus
startup and seek tests. Sintel's player advanced by 120 seconds in each
120-second viewing window. WebM advanced by only 55.4 and 88.2 seconds.

Sintel's listing reported 22 seeds, but the runs reached only seven or eight
connected peers. WebM listed 14 seeds and reached two peers in its playable
runs; the metadata failure reached one peer without obtaining metadata.
Peer count does not distinguish uploading seeds from other peers.

The user experience verdict follows the observed waits and stalls, not an
industry benchmark threshold. A 16–21-second cold start is tolerable for a
prototype but slow. Sustained Sintel playback was effectively smooth in
these short tests. Waiting 19–24 seconds after a late seek, or 12–19 seconds
for rapid scrubbing to settle, is cumbersome. WebM's 16–23 interruptions in
two minutes and a failed third start make it unsuitable for dependable viewing.

## What to improve first

1. **Prevent repeated playback starvation.** Measure available useful payload
   rate against media consumption and use a startup/rebuffer threshold with
   a larger or adaptive demand window. Starting WebM in ten seconds was not a
   success when it immediately led to sustained stalls. Insufficient swarm
   bandwidth cannot be fixed with buffering alone; surface that condition.
2. **Reduce seek recovery time.** Compare priority/deadline handling and a byte
   budget for look-ahead with the current five-piece policy. Sintel's 8 MiB
   pieces give a roughly 40 MiB demand window, whereas WebM's 256 KiB pieces
   give only 1.25 MiB. This asymmetry is a concrete candidate for a controlled
   experiment, not a proven explanation for either result.
3. **Make readiness honest.** Distinguish obtaining metadata, fetching startup
   data, playable buffer, and stalled playback. Listed seeds are insufficient
   to promise a quick start. Preserve failure evidence and avoid calling a
   functional seek check a smooth-playback pass.

Supporting measurements: Sintel peak resident memory was 168–187 MiB and
mean process CPU 30.5–33.7%; playable WebM runs peaked at 176–181 MiB and
averaged 27.3–36.4%. These are supporting process observations; the usability
verdict rests on startup, progression, stalls and seeks.

The source is Pirate Bay's `https://apibay.org/q.php` API; the test media are
Sintel (`43F4001DE4AB25D521C63684E2B69804193ED9D9`) and Tears of Steel WebM
(`02767050E0BE2FD4DB9A2AD6C12416AC806ED6ED`). Current listings were fetched
before running the matrix. Preserve the recorded counts when comparing runs.
