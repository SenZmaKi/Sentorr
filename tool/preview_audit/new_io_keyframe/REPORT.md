# Live keyframe run with new stream I/O

Process 89789, 2026-10-24. Recorded test window 17:43:58–17:45:00 Africa/Nairobi.
Profile app, packaged mpv 0.36, VideoToolbox main playback. New verified range-read
path and thumbnail resizing were both active; changes cannot be separately
attributed by comparing against the older live recording.

- Ten extractions completed without errors/timeouts; eleven cache hits recorded.
- Median extraction 110 ms (26–499); median request completion 283 ms (160–680).
- Capture median 16.5 ms (10–36), compared with 1238 ms in the earlier live run.
- JPEG median 27,000 bytes (22,552–37,083), all verified at 240×120.
- No reported decoder/output drops. Peak whole-app sampled RSS 345.8 MiB.
- Whole-process CPU intervals overlapping extraction: median 58.2% across nine
  one-second intervals. Playing/non-buffering intervals without extraction:
  median 39.4% across ten intervals. These are observational bins, include other
  work and partial overlap, and do not isolate causal decoder CPU cost.

## Correctness caveat

Two apparent successes were stale: target 410 s returned 469.5 s, and target
320 s returned 386.333 s. Thus ten successful extractions do NOT establish ten
correct previews. Three other results were discarded after the pointer moved.
The initial readiness check could see seeking=no before mpv began processing the
new seek. The faster path exposed this race.

Before the following exact-frame run, the extractor was changed to wait for
MPV_EVENT_SEEK followed by MPV_EVENT_PLAYBACK_RESTART through a dedicated native
client event queue. It does not consume MediaKit's queue or rely on coalesced
property observations. The precise run also disables ten-second target rounding;
controller targets retain millisecond resolution. Both changes must be disclosed
when comparing success/latency between these sessions.

The captured sample is small and manually operated. CPU medians are not
per-extraction CPU costs; memory totals include torrent, player and Flutter.
`events.json` and `cpu.jsonl` retain the test-window records saved before shutdown.
