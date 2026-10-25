# Exact versus keyframe previews

2026-10-24, Apple M1, arm64 debug Flutter tester and Homebrew libmpv 0.41.
Same source fixtures, two decoder threads, 240×136 bounding box, 1 MiB demuxer
budget and timeouts as the first iteration. The app preview extractor now defaults
to keyframe mode; exact mode remains available through its constructor for audits.
The existing experimental UI flag is unchanged pending the user's enablement decision.

## Results

Both modes were rerun in the same session. The keyframe extraction-only pass was
repeated after adding frame-content assertions; values below use that repeat.
Five seeks per fixture at 1, 5, 8, 2 and 6 seconds. Median includes cold opens,
JPEG encoding and Flutter decoding; failed attempts are excluded from medians.

| Fixture | Exact success | Exact median | Keyframe success | Keyframe median | Speedup |
| --- | ---: | ---: | ---: | ---: | ---: |
| H.264 | 5/5 | 378 ms | 5/5 | 75 ms | 5.0× |
| HEVC | 5/5 | 755 ms | 5/5 | 70 ms | 10.8× |
| AV1 | 5/5 | 731 ms | 5/5 | 65 ms | 11.2× |
| 4K60 HEVC | 4/5 | 1259 ms | 5/5 | 105 ms | 12.0× |

Keyframe latency ranges: H.264 70–479 ms, HEVC 65–126 ms, AV1 57–99 ms,
4K60 HEVC 73–213 ms. The original exact audit succeeded on only 9/20 requests;
this rerun succeeded on 19/20. Absolute reliability/latency are sensitive to
machine load and cannot be inferred from one short run. The paired measurements
still show a substantial keyframe advantage on every fixture.

The headless playback comparison repeats uncached requests with a 500 ms gap
for at least five seconds. Cache/debounce are bypassed to expose extraction cost.
Average CPU is process CPU seconds divided by wall seconds; 100% is one CPU core.

| Fixture | Exact baseline → previews | Keyframe baseline → previews | Exact outcomes | Keyframe outcomes |
| --- | ---: | ---: | ---: | ---: |
| H.264 | 38.4% → 113.4% | 36.8% → 50.2% | 6/6 | 9/9 |
| 4K60 HEVC | 158.2% → 324.9% | 137.0% → 178.0% | 2/3 | 9/9 |

Compared with each mode's baseline, CPU overhead fell from 75 to 13.4 percentage
points for H.264 and from 166.7 to 41 for 4K60 HEVC. This is a timed throughput
comparison, not a fixed request-count or isolated per-request CPU measurement.
Keyframes completed more requests during the measurement window. Process RSS
includes retained allocations across earlier fixtures, so it is not used to
claim a decoder-memory reduction.

## Accuracy and freshness

The captured frame's actual timestamp is kept with its cached JPEG for diagnostics.
The YouTube-style UI shows only the pointer timestamp in a separate pill below
the rounded thumbnail. The image is approximate; the main seek action still uses
the exact pointer position. Preview approximation never changes playback seeking.

H.264 and 4K60 HEVC requests landed at 0 or 4.167 seconds, up to 3.833 seconds
before their targets. The short HEVC and AV1 fixtures landed at 0 for all requests,
up to eight seconds before the target: these previews are fast but repetitive.
The timestamp error depends on keyframe spacing, not the size of the thumbnail.
The 10-second UI cache buckets can add further distance from the pointer target.

Native tests record screenshot SHA-256 and captured timestamps. H.264 and 4K
hashes change when seeking to a different keyframe, and return to the same hash
when seeking back, guarding against simply returning a stale screenshot. This
covers the supplied moving fixtures, not every codec/container or decoder race.
Controller tests verify that actual frame timestamps survive cache hits.

## Reproduce and inspect

```sh
SENTORR_PREVIEW_AUDIT=1 SENTORR_PREVIEW_MODE=exact flutter test test/player/preview_native_audit_test.dart --reporter expanded
SENTORR_PREVIEW_AUDIT=1 SENTORR_PREVIEW_MODE=keyframe flutter test test/player/preview_native_audit_test.dart --reporter expanded
```

Raw files: `exact_native_results.json`, `keyframe_native_results.json`,
`exact_playback_results.json`, `keyframe_playback_results.json`. The unprefixed
files preserve the original first-iteration audit.

This remains a debug/headless local-file comparison using Homebrew's library.
It does not establish packaged release performance, rendered frame drops,
hardware-decoder contention, or behavior with live incomplete torrents. The
verified-pieces-only endpoint and its no-download-demand policy are unchanged.
No browser inspection or foreground app launch was performed.
