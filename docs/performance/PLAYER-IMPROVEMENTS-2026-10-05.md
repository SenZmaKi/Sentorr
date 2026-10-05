# Player performance adjustments — 5 October 2026

## Changes

- Native playable-cache wait is five seconds, down from ten. This controls
  startup and resuming after buffering; it does not promise a five-second start.
- Piece scheduling skips unchanged demand windows. Cancellation, changed file
  priorities, and advancing to another piece still update native priorities.
- Single-piece reads return read-only views of cached bytes. Cross-piece reads
  still allocate and copy; views remain valid after cache eviction.
- HTTP reads remain 64 KiB. The first chunk flushes immediately; subsequent
  flushes batch at most 256 KiB, retaining bounded socket backpressure.
- Hidden player bars unmount after fading out, releasing stream subscriptions
  and control animations. Showing them reads current state. Playback, buffering,
  subtitles, and Up Next continue independently.
- Parked torrent sessions expire after five idle minutes. Taking one for playback
  cancels expiry; replacing one restarts the timer. Provider disposal also closes
  held sessions, and one close failure cannot prevent subsequent cleanup.

## Local comparison

A temporary Dart benchmark compared the previous scheduler, byte reader, and
HTTP server from commit `16eb5b9` with the changed code in the same process.
It used synthetic cached pieces, no native torrent reads, and no decoding.
Read and transfer results are medians of five alternating runs after warmup.

| Workload | Previous | Changed |
| --- | ---: | ---: |
| 128 MiB of cached reads in 64 KiB chunks | 17.759 ms | 3.684 ms |
| 64 MiB over loopback HTTP | 70.728 ms | 61.516 ms |

The cached fixture was 8 MiB with 256 KiB pieces. The transfer workload requested
it eight times. Loopback transfer time was about 13% lower in this run. These
figures cover the combined byte-path changes, not an isolated flush improvement.

A separate 100,000-repeat unchanged-window probe reduced base-priority evaluations
from 3,200,000 to 32. UI regression checks confirm hidden bars stop receiving
updates after the fade and resubscribe with fresh state when shown.

These measurements do not establish public-swarm throughput, decoding/frame-rate
improvements, or whole-app CPU/memory savings. Native loopback session tests cover
exact byte ranges, seek cancellation, paused-seed recovery, independent session
ownership, and cleanup. Further whole-app measurements need a controlled playback
workload and native memory accounting.

## Validation

- 89 player/UI tests passed, including hidden-bar subscription and fade-reversal
  checks and parked-session expiry, takeover, replacement, and disposal.
- 26 selected torrent-stream tests passed, including the new scheduler/read tests,
  multi-batch HTTP delivery, first-chunk responsiveness, and native loopback tests.
- Scoped Flutter/Dart analysis and whitespace checks passed.
