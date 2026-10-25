# Five-second keyframe previews with retained images

Live manual test on 2026-10-25, Profile macOS app PID 64948, Apple M1, packaged
mpv 0.36, VideoToolbox main playback, 1080p 10-bit HEVC source. The new stream
range-read path, native 240-pixel resizing and seek-event readiness guard were
active. Preview targets used five-second buckets and 180 ms debounce. No browser
or automated UI inspection was performed.

## Measured results

All 29 extraction attempts completed successfully, with no recorded errors,
timeouts or rejected output dimensions. Twenty-one completed results were selected
for display; eight were correctly discarded after the pointer moved. There were
43 cache hits, in addition to the extraction attempts.

| Metric | Minimum | Median | p95 | Maximum |
| --- | ---: | ---: | ---: | ---: |
| Request completion, including debounce/queue | 236 ms | 308 ms | 552 ms | 595 ms |
| Extraction | 55 ms | 126 ms | 207 ms | 371 ms |
| Keyframe seek | 44 ms | 109 ms | 189 ms | 298 ms |
| Capture/JPEG | 9 ms | 16 ms | 23 ms | 24 ms |

The p95 is the nearest-rank value across these 29 attempts. Request completion is
measured through image-byte selection, not physical display presentation. Cached
requests bypass extraction; their displayed latency was not measured separately.

Every JPEG was verified at 240×120. Median encoded size was 25,134 bytes, maximum
44,923 bytes. The source still determines keyframe spacing: a five-second cache
bucket does not guarantee a frame within five seconds of the target. The largest
bucket-to-frame distance was 7.292 seconds; all decoded timestamps were at or before
the requested bucket. No conspicuous future-position stale results like the earlier
readiness race were recorded. This timestamp check alone is not visual certification
of every frame.

## Retention and theme behavior

There were 33 `retained` events during movement between eligible downloaded
positions, including rapid transitions whose requests were later debounced or
served from cache. Seven extraction starts explicitly reported a previous image
still held; other starts had no eligible previously displayed image at that time.
These counts are not 33 separate successful replacement extractions.

Controller/layout tests establish no empty notification between eligible retained
and replacement images, source/unavailable-region clearing, and dark image backing
in both themes. Logs establish controller retention decisions, not whether the
user perceived any remaining flash. Actual white video frames remain white; the
change removes the light-theme backing behind an image while it decodes. The
border and timestamp pill remain theme-aware.

## Main playback and resource impact

The comparison window spans five seconds before the first extraction through
five seconds after the last: approximately 11:02:49–11:03:40 Africa/Nairobi.

- No output or decoder drops were reported in the window.
- No buffering transitions or actual playback seek actions were recorded. This
  session therefore measures hover/scrub previews during playback, not recovery
  after an actual playback seek.
- Maximum sampled absolute A/V difference was approximately 10.7 ms.
- Maximum Flutter build/raster stage times were 8.623 / 11.093 ms. These are
  separate UI stage maxima, not native video presentation latency.
- Whole-process RSS peaked at 240.4 MiB in the interaction window. RSS includes
  the main player, torrent engine, Flutter, preview decoder and retained caches;
  it is not isolated thumbnail memory or a leak test.
- One-second CPU intervals overlapping extraction while playing: median 53.4%
  across 25 intervals, range 41.8–89.3%. Playing/non-buffering intervals without
  extraction: median 38.4% across 20 intervals, range 22.9–42.6%.

100% CPU is one occupied core. These process-wide bins include other app work
and partial extraction overlap. The approximately 15-percentage-point difference
is observational and does not isolate causal per-request extraction CPU.

## Comparison and conclusion

The prior ten-second keyframe session had a 114 ms extraction median and 291.5 ms
request median after excluding two known stale results. This five-second run had
126 / 308 ms respectively, with 29/29 completed requests and the readiness fix.
The exact-frame run had 475 / 937 ms medians and one failed attempt out of ten.

Five-second previews remained responsive in this larger manual hover test. There
is no evidence here of a major performance penalty from using finer buckets or
retaining the previous image. This is not a controlled proof of equal performance:
timeline positions, pointer movement, cache reuse and readiness behavior differed
between sessions. No production behavior was changed while analyzing this run.

Artifacts: `events.json` and `cpu.jsonl`. CPU sampling attached at app startup.
