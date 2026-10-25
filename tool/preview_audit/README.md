# Seek preview experiment and performance audit

The current extractor uses keyframe seeking. See [the comparison](COMPARISON.md)
for the exact-seek rerun, keyframe measurements and frame-accuracy trade-off.
The initial measurements below describe the first exact-seek iteration.

Seek previews are integrated into normal builds with five-second keyframe buckets;
no feature or experiment dart-defines are required. The measurements below retain
the history of the initial exact-seek experiment. No browser inspection was used.

## Implementation

Hover/drag requests are debounced 180 ms and grouped into five-second buckets.
The last displayed thumbnail is retained immediately on hover movement. After
180 ms debounce, deferred validation checks unrounded indexed download coverage.
A reported incomplete target hides the retained image without extraction; unknown
coverage keeps it visible while extraction tries. This is conservative whole-index
interval coverage, not proof that an individual keyframe cannot be decoded.
Late validation results are discarded after pointer/source changes. Cache hits
show their own image immediately. No spinner or skeleton replaces/overlays the
retained image while a new preview loads. Leaving the seek bar or switching source clears
the held image. Preview reads still never request missing torrent pieces. Image.memory uses gapless replacement and a
dark video backing in both themes; the border and time pill follow the app theme.
A single paused MediaKit player uses `vo=null`, no audio/subtitles, software
decoding limited to two threads, a 1 MiB demuxer budget, and the built-in `format` conversion filter
bounded to 240×136 while preserving source display aspect ratio. Decoder output
and encoded JPEG dimensions are checked; resizing failures abandon the attempt
before full-resolution JPEG encoding. It waits for initial media readiness before seeking, then
waits for mpv's seeking flag to clear and the requested timestamp to be reached
before taking a JPEG screenshot in exact mode. Keyframe mode waits for seeking
to finish without requiring the frame timestamp to match the target. The bubble
shows the pointer timestamp below a rounded, theme-aware thumbnail; captured
frame timestamps remain available in the controller and audit output. It owns no Flutter video texture.

The controller permits one extraction at a time, keeps only the latest pending
target, rejects obsolete results, suppresses repeated failures for five seconds,
and bounds the JPEG cache to 48 entries / 8 MiB. Evictions also remove matching
Flutter image-cache entries. Work has an outer three-second timeout; failed
attempts dispose their decoder so unfinished seeks cannot continue indefinitely.
Native disposal itself is asynchronous and is not a hard real-time deadline.
The extractor has two-second readiness/seek polling limits. It does not start
new work while the main player is buffering/seeking. Already-running work can
continue until completion/timeout. Main playback and preview positions are
independent.

The loopback `/preview` route has a separate ByteSource: all pieces for each
read must already be verified by libtorrent before native disk reads are issued.
It never calls the piece scheduler or playback startup bookkeeping, and its
release cannot cancel playback demand. The current engine reads bounded verified
ranges directly from disk. The whole-piece fallback retains at most one verified
piece up to 4 MiB; larger fallback pieces are not cached. Missing pieces terminate the HTTP body and leave the timestamp-only
bubble. Completed local files are supported; peer streams are excluded.

## Reproduction

From the repository root on macOS with Homebrew mpv:

```sh
SENTORR_PREVIEW_AUDIT=1 SENTORR_PREVIEW_MODE=keyframe flutter test test/player/preview_native_audit_test.dart --reporter expanded
```

`SENTORR_AUDIT_LIBMPV` can override the library path. The ordinary test suite skips
this environment-specific audit. Fixtures live under `tool/codec_lab/assets/media`.
The test writes `<mode>_native_results.json` and `<mode>_playback_results.json`
here. Use `SENTORR_PREVIEW_MODE=exact` to repeat the first implementation.
The unprefixed JSON files retain the original audit.

## Initial results

Apple M1, arm64 Flutter tester, Homebrew libmpv 0.41, debug test runner.
Extraction order per file: 1, 5, 8, 2, 6 seconds; failed attempts dispose the decoder.
Successful timings include initialization when needed, seek, JPEG capture and
Flutter image decoding. Raw rows include total process RSS, not decoder-only RSS.

| Fixture | Successful attempts | Successful latency |
| --- | ---: | ---: |
| H.264 MP4 | 4/5 | 541–1694 ms |
| HEVC MP4 | 3/5 | 812–1781 ms |
| AV1 MP4 | 2/5 | 976–1679 ms |
| 4K60 HEVC MKV | 0/5 | none within the budget |

The playback comparison uses a second continuously playing, headless software
decoder with audio disabled. Each phase runs for at least five seconds. Preview
attempts are separated by 500 ms; this deliberately measures uncached work,
bypassing the UI debounce/cache. CPU is cumulative process CPU time from `ps`
divided by elapsed wall time; 100% means one fully occupied CPU core.

| Fixture | Baseline average CPU | With extraction | Preview outcomes |
| --- | ---: | ---: | ---: |
| H.264 | 35% | 120% | 6/6 |
| 4K60 HEVC | 348% | 445% | 0/2 |

H.264 process RSS grew about 72 MiB during the extraction phase versus 11 MiB
in the baseline phase. Sequential phases and allocator retention prevent treating
this as an isolated decoder memory measurement. Peak RSS across the independent
fixture extraction run was approximately 509 MiB, including Flutter/test overhead
and allocations retained from earlier fixtures.

## Interpretation and limits

The downloaded-only boundary prevents preview network demand, but does not make
random-access decoding cheap. Exact seeks can decode long GOPs at full source
resolution before scaling. Two decoder threads and short timeouts bound exposure,
but 4K frequently consumes the entire budget without a usable result.

These are initial, single-pass measurements on short complete local fixtures with
other applications running. They do not establish release-mode latency, rendered
frame drops, audible smoothness, thermal behavior or real incomplete-torrent disk
performance. The 4K main playback decoder is itself software-bound; its position
wraps/lag cannot establish a visible playback stall. Tests verify the downloaded-only
policy and route isolation using fake sources, not a live swarm.

Loading the existing app's bundled Mpv.framework in flutter_tester failed because
its @rpath dependency Ass.framework could not resolve, including with a framework
path override. Therefore Homebrew results must not be treated as bundled-library
compatibility validation. Android, Windows and Linux were not run.

Before default enablement: profile with the packaged library in a release build,
measure rendered playback while extraction runs, test incomplete MP4/MKV files,
and compare keyframe-only seeks with exact seeks. Keyframe-only extraction could
avoid much of the GOP decode cost but requires displaying/accepting approximate
frame timestamps. Full-resolution hardware extraction is another experiment,
with separate contention and platform constraints.

## Live playback diagnostics

The former `SENTORR_PREVIEW_DIAGNOSTICS` sampler has been removed. Open
Stats for Nerds for request-driven preview counters, last and average extraction
latency, total request latency (including debounce), and bounded JPEG cache usage.
These metrics are included in copied stats and recordings through the existing
Stats for Nerds sampling path. Preview requests no longer enter the playback-event
log or produce a separate audit log, timer, or Flutter frame callback.
Historical reports below describe the instrumentation used at the time.

For aligned process CPU/RSS samples:

```sh
python3 tool/preview_audit/sample_process.py PID /tmp/sentorr-preview-cpu.jsonl 900
```

The sampler exits after the requested duration or when the process disappears.
Leave a short hover-free playback baseline, then hover uncached positions, revisit
cached positions and perform real seeks. Compare hovering against playing/paused
baselines separately; buffering after a playback seek is not evidence that preview
work caused a stall. Native-property polling and logging add a small unmeasured
instrumentation cost. Empty/unsupported native properties stay explicit in logs.

The CPU sampler also accepts `--wait-for-sentorr` instead of PID. Start it before
launching the Profile app to attach within approximately 250 ms of process creation:

```sh
python3 tool/preview_audit/sample_process.py --wait-for-sentorr /tmp/sentorr-preview-cpu-resized.jsonl 900
```

This local helper waits up to 180 seconds for this workspace's Profile executable.
The latest extractor records target, decoder output and JPEG dimensions alongside
phase timings. `SENTORR_AUDIT_OUTPUT_PREFIX` keeps new harness output separate
from prior benchmark artifacts.

## Exact-frame comparison harness

The normal app uses five-second keyframe previews. Exact mode remains available
in the test harness with `SENTORR_PREVIEW_MODE=exact`; it is no longer selected
through an application dart-define. Tests can construct PreviewController with
millisecond buckets and PreviewExtractor with PreviewSeekMode.exact. The 180 ms
debounce, single pending request and small-image checks remain identical.
The extractor waits for SEEK then PLAYBACK_RESTART on a separate mpv client queue
before capture. Reading a false seeking flag alone could otherwise return an old
frame before the new seek began; the live new-I/O audit exposed that race.
