# Live comparison: exact frames versus keyframes after stream I/O changes

Recordings were made on 2026-10-24 on the same Apple M1 macOS machine, Profile
Sentorr build, packaged mpv 0.36.0, 1080p 10-bit HEVC media and VideoToolbox main
playback. The preview decoder used software decoding with two threads. Both
sessions included the new verified direct-range I/O path and native thumbnail
resizing. This report was completed on 2026-10-25.

## Result

Exact frames are substantially more accurate but remain slower and more CPU
intensive. The improved I/O and thumbnail sizing removed the earlier bottlenecks;
now decoding forward to the exact target accounts for approximately 98% of
successful extraction time. JPEG capture remains inexpensive.

| Observation | Keyframe run | Exact-frame run |
| --- | ---: | ---: |
| Attempts | 10 | 10 |
| Generated images | 10, including 2 known stale frames | 9 |
| Median successful extraction | 114 ms, excluding known stale frames | 475 ms |
| Median request completion | 291.5 ms, excluding known stale frames | 937 ms |
| Successful extraction range | 95–499 ms, excluding stale frames | 276–1813 ms |
| Median capture/JPEG time | 16.5 ms, all generated frames | 10 ms |
| Cache hits | 11 | 0 |
| Median CPU while playing, intervals overlapping extraction | 58.2% (9 intervals) | 100.5% (15 intervals) |
| Median playing CPU without extraction | 39.4% (10 intervals) | 38.5% (5 intervals) |
| Peak whole-app RSS in interaction window | 345.8 MiB | 386.6 MiB |
| Reported output drops | 0 | 2 |
| Reported decoder drops | 0 | 0 |

100% CPU represents one occupied CPU core, not the entire machine. CPU bins are
one-second intervals overlapping extraction, assigned to playing/paused using the
nearest native sample. They include main playback, UI, torrent activity and other
process work; these medians are observational, not isolated per-extraction costs.
RSS totals include all app/native allocations and do not isolate decoder overhead.

## Exact-frame outcomes

Nine images were generated, with reported decoded timestamps within 32 ms of the
requested target. All were verified at 240×120. Two completed images were discarded
because the pointer had moved; seven were selected for display. No obsolete-result
discard was counted as an extraction failure.

Successful hover requests completed in 457–2195 ms, median 937 ms, including
180 ms debounce and any wait behind previous extraction. One new pointer position
waited behind an obsolete 1813 ms extraction: its own extraction took 332 ms,
but overall completion took 2195 ms. Thus the single-worker policy bounds resource
use but a slow obsolete request can delay a fresh target.

One request at 1704.669 seconds failed the seek-readiness budget, taking 2105 ms
for the attempt and 2287 ms including debounce. This recording does not distinguish
unavailable source bytes from slow decoding/seek readiness for that failure.
No cache hits were recorded in the exact run, consistent with millisecond cache
keys and different pointer targets. Cache performance was not controlled between
runs.

## Playback observations

There were no buffering transitions or actual playback seek actions during the
exact run's interaction window. Two output drops appeared in samples at 17:50:37
and 17:50:38 Africa/Nairobi, close to extraction activity. Decoder drops remained
zero. This is a small observed presentation cost, not proof of a causal preview
stall. Sampled absolute A/V difference peaked at approximately 10.7 ms.

Flutter stage maxima within the comparison window were 8.816 ms build and
9.439 ms raster, both recorded before the first extraction. These measure UI
work, not native video frame presentation. No browser or UI automation was used.

## Comparison limits and readiness correction

These were manual sessions at different timeline positions, with different seek
and pointer patterns. The exact run disabled ten-second cache buckets and used
millisecond targets, so it naturally offered fewer cache reuse opportunities.
It also included a frame-readiness correction absent from the keyframe recording.
The keyframe run's stale targets were 410→469.5 s and 320→386.333 s. They are
excluded from its successful timing medians above but are present in raw data.

The correction waits for MPV_EVENT_SEEK followed by MPV_EVENT_PLAYBACK_RESTART
using a dedicated client queue. Property observations can coalesce away a short
true→false seeking transition; checking only a false flag could read the old frame.
Standalone fixture checks passed 20/20 keyframe attempts and 19/20 exact attempts
after this change. Those tests used Homebrew's library, while the live exact run
above used the packaged library. A fresh keyframe session with the correction is
needed for a fully matched A/B comparison.

These data support a responsiveness/precision trade-off, not a universal speedup,
CPU multiplier, memory regression or reliability guarantee across devices/media.

## Recommendation

Use corrected keyframe previews as the responsive default. Exact previews are
viable when precision is desired, but can take one to two seconds, consume about
a CPU core during this session, and time out on some targets. A later hybrid could
show a keyframe first and refine only after the pointer settles, but this was not
implemented or benchmarked here. No runtime mode was changed during this audit.

Artifacts: `events.json` (PID 93667) and `cpu.jsonl`; comparison keyframe artifacts
are in `../new_io_keyframe/`. Interactions were restricted to five seconds before
the first extraction through five seconds after the last completed attempt when
computing window-based memory, CPU and presentation figures.
