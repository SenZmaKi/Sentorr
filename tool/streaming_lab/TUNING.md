# Smoothing experiments and lab defaults

Measured 2026-10-02 on macOS arm64. This follows USABILITY.md and implements
real changes in the isolated lab, not the production torrent feature.

## Implemented

- Playback initializes at volume zero. Mute/unmute is available beside the
  playback controls and volume is applied before opening media.
- The player targets 60 seconds of forward packet cache, bounded by 64 MiB,
  with 16 MiB of backward packet cache. The conservative default requires
  10 seconds of buffered media before initial playback or recovery from a
  cache underrun. This also affects seek recovery. The lab offers 5, 10, 20
  and 30 seconds as alternatives.
- Torrent demand is a 16 MiB window rather than a fixed five pieces. For
  8 MiB pieces this becomes two pieces instead of five; for 256 KiB pieces it
  becomes 64 instead of five. Piece rounding and file ends affect the actual
  window. This is separate from mpv's media-time cache.
- The copied-piece LRU grows from 8 to 24 MiB so alternating readers can keep
  more than one 8 MiB piece. A piece exceeding that budget is not retained.
- Unchanged priorities/deadlines are no longer resent on every 64 KiB HTTP
  chunk. Requests still combine demand, cancel obsolete seeks, and serve
  only verified piece data. No zero filling or incomplete-file EOF was added.
- The loading overlay shows actual mpv cache duration, checks `paused-for-cache`
  and detects a playing position that has stopped advancing. MediaKit's
  buffering flag alone missed a freeze with the changed cache policy.
- After 30 seconds of waiting the overlay explains that the source may be
  too slow and offers stopping/trying another torrent. Stop remains available
  during loading. This is an informational threshold, not a forced start:
  beginning playback with insufficient data would recreate the original issue.

mpv's readiness wait can end earlier at EOF or when the byte/cache limits
prevent further prefetch. Therefore these values are targets, not guarantees
that every source has exactly ten seconds ready. The options and limits follow
[mpv's cache documentation](https://mpv.io/manual/stable/#cache).

## Controlled bandwidth results

Local torrent seed, synthetic H.264/AAC video, 180 seconds, 182,892,966 bytes,
approximately 8.13 Mbps. The seed is unrestricted; the downloader is capped.
Mbps is decimal megabits; native limits use `Mbps × 1,000,000 / 8` bytes/s.
This emulates payload throughput, not Wi-Fi latency, packet loss or congestion.
First playback includes local seeding/verification setup, typically 2–3 seconds.

| Cap | Ready target | First progress | Viewing window | Video progression | Late seek | Backward seek | Rapid seeks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 5 Mbps | 10 s | 29.79 s | 90 s | 61.17 s | 28.95 s | 4.09 s | 0.92 s |
| 10 Mbps | 10 s | 22.84 s | 90 s | 90.00 s | 24.73 s | 3.66 s | 2.95 s |
| 20 Mbps | 10 s | 13.51 s | 90 s | 90.04 s | 3.35 s | 3.86 s | 2.94 s |
| 40 Mbps | 10 s | 10.73 s | 90 s | 90.00 s | 3.56 s | 3.66 s | 3.46 s |
| 10 Mbps | 5 s | 17.10 s | 60 s | 60.00 s | 18.48 s | 4.11 s | 1.00 s |
| 40 Mbps | 5 s | 9.06 s | 60 s | 60.00 s | 5.43 s | 2.89 s | 2.17 s |

At 5 Mbps, three buffering intervals consumed 29.04 seconds of the 90-second
window. At 10/20/40 Mbps with the ten-second target, the player sustained the
full window with one roughly 0.2-second buffering event. The smaller-target
refinement also sustained its full windows; final-build cache telemetry in the
40 Mbps run reported no waiting samples during viewing and grew to 60 seconds
of cached media. All completed controlled runs paused/resumed correctly.

The first controlled 10/20/40 runs sought to 50% after playing for 90 seconds
of a 180-second video. Their near-zero middle-seek timing was not meaningful
and is excluded. The refined harness waits at least 650 ms after a seek before
checking progress and records the previous position. At 40 Mbps/5 seconds,
its distinct middle seek after a 60-second viewing window took 0.86 seconds;
at 10 Mbps it took 12.67 seconds. Those segments may already be prefetched.

Cached history differs between the 90-second and 60-second experiments, so
seek results are observations, not an isolated A/B estimate. Three-second
cached seeks do not establish three-second cold seeks across the full file.

## Real-swarm results

Public torrent hashes are the same Sintel and Tears of Steel WebM used in
USABILITY.md. All runs capped download at 40 Mbps; actual peer delivery was
lower. The tests intentionally retain failures.

| Source | Ready target | First progress | Viewing progression | Seek outcome |
| --- | ---: | ---: | ---: | --- |
| Sintel | 10 s | 25.57 s | 90/90 s | Middle 17.73 s, late 16.59 s, backward 5.29 s, rapid 23.71 s |
| Sintel | 5 s | 22.20 s | 60/60 s | Middle 12.57 s, late 9.81 s, backward 3.61 s, rapid 20.80 s |
| WebM | 10 s | 58.81 s | 8.60/90 s | Middle seek timed out after 45 s |
| WebM | 20 s | 56.31 s | 50.50/90 s | Middle seek timed out after 45 s |

Sintel stayed smooth, but extra readiness waiting increased startup and some
seek times relative to the earlier small-cache baseline. Its late seek improved
in these samples. WebM delivery was much weaker in these runs; the ten-second
case's final native rate was about 1 KiB/s with one peer. No buffer can sustain
media consumption when the swarm persistently supplies less than the bitrate.
These are not matched-capacity before/after runs, so we cannot claim that the
buffer changes caused WebM's slowdown or that twenty seconds is universally
better than ten.

MediaKit's raw buffering durations underreported the WebM freezes; the decisive
measurement is lost video progression, 81.4 and 39.5 seconds respectively.
The final build includes the additional cache/position monitor. Earlier pilot
volume samples for external sources were taken after metadata but before the
player opened; their value of 100 is not an audio playback test. The final-build
refinement checks volume after progressing playback and confirms zero for
both controlled runs and Sintel. Raw reports are preserved with their sampling
context; sanitized summary renames the earlier field.

## Defaults and eventual settings

The lab ships with **40 Mbps download cap, 10-second ready target, 60-second
forward cache target, 64 MiB forward packet budget, 16 MiB native demand window,
24 MiB copied-piece cache, and muted audio**. The 40 Mbps cap matches the
requested connection for these experiments; it is not a claim about worldwide
average speed or a suitable universal production download cap.

Expose these user-level choices in production settings:

| Setting | Suggested behavior |
| --- | --- |
| Playback preference | Smooth: 10-second ready target; quicker start: 5 seconds; extra reserve: 20–30 seconds |
| Download bandwidth cap | Unlimited/automatic by default, plus custom Mbps; 40 Mbps for this lab |
| Forward buffer target | 30/60/120 seconds as an advanced setting, subject to memory budget |
| Memory budget | Advanced bounded presets; needs device testing before mobile defaults |

Keep piece priorities, deadlines, native copied-piece LRU and HTTP read chunk
size internal. Most users should not need to understand those mechanisms.
Readiness on seek and after starvation can eventually have separate targets;
that combination is not measured by this matrix and is not implemented as a
separate setting here.

Ten seconds is a conservative provisional choice, not a proven optimum for
all networks. Five seconds reduced startup by 1.7 seconds at 40 Mbps and 5.7
seconds at 10 Mbps without a stall in the short controlled windows. A longer
ready target helps reserve-building but cannot fix insufficient average supply.
A future automatic profile should compare useful delivery rate with actual
media consumption and recommend another source/quality when capacity is
insufficient. Retry/reconnect behavior after a failed or abandoned HTTP read
also deserves a targeted test; the diagnostic monitor explains a freeze but
does not repair the public swarm.

## Reproduction and validation

```sh
python3 tool/prepare_bandwidth_fixture.py
flutter build macos --release
python3 tool/tuning_audit.py
python3 tool/summarize_tuning.py
```

To repeat only the refinement:

```sh
STREAMING_TUNING_CASES=controlled-40-ready5,controlled-10-ready5,sintel-5 \
STREAMING_SUSTAINED_SECONDS=60 python3 tool/tuning_audit.py
```

The environment knobs are `STREAMING_DOWNLOAD_MBPS`,
`STREAMING_BUFFER_SECONDS`, `STREAMING_RESUME_SECONDS`, and
`STREAMING_READAHEAD_MIB`. Controlled seed caps use
`STREAMING_CONTROLLED_MBPS`; when absent, the existing controlled smoke mode
keeps its 256 KiB/s seed/download limits. UI changes apply to the next session.

Evidence: `validation/tuning-summary.json`, plus ignored raw
`validation/tuning*.local.json` reports. This is ten sequential runs on one
host, without a browser or subjective audio/video quality review. It does not
establish mobile memory use, high-bitrate 4K behavior, loss/jitter resilience,
or statistically stable percentiles. There is no matched legacy controlled
benchmark, so implementation CPU gains are not quantified.

The final release passed static analysis and seven HTTP transport tests.
The real native torrent/HTTP smoke test passed after the scheduler/cache
changes, including byte integrity, incomplete-file reads, seed stalls and
recovery. Final-build playback also verified mute volume zero, cached-time
telemetry, normal playback, seeks, pause and resume.
