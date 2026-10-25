# Live seek-preview audit — 2026-10-24

Profile macOS app, Apple M1, packaged mpv 0.36.0; main playback reported
VideoToolbox hardware decoding. User operated the player manually and quit it
when finished. App logs preserved 37 one-second samples from 17:07:15–17:07:52
Africa/Nairobi, seven completed preview extractions and three playback seeks.
No browser or UI automation was used to inspect the session.

## Verdict

All seven uncached preview requests succeeded and were displayed. There were no
reported decoder or output drops. Responsiveness is limited by screenshot capture
and JPEG encoding, rather than keyframe seeking. A separate native reproduction
confirms the packaged runtime rejects the configured thumbnail filter property,
leaving full-resolution capture in place. Fix that before further tuning seeking.

## Measured preview response

| Metric | Minimum | Median | Maximum |
| --- | ---: | ---: | ---: |
| Extraction, excluding debounce/queue wait | 976 ms | 1383 ms | 2232 ms |
| Request through extraction completion | 1158 ms | 1563 ms | 2414 ms |
| Keyframe seek | 0 ms | 186 ms | 303 ms |
| Capture/JPEG | 792 ms | 1238 ms | 1409 ms |

Capture consumed 80% of total extraction time across these seven attempts.
The first cold open added 690 ms. Every request waited approximately 180 ms for
debounce. JPEGs ranged from 501,663 to 1,389,281 bytes, median 1,093,004 bytes.
The final encoded-image cache held 7,317,260 bytes (6.98 MiB), close to its 8 MiB
cap after only seven entries. There were no cache hits, failures, timeouts or
stale-result discards in this session; cache-hit latency is therefore unmeasured.
These timestamps measure extraction completion and selection for display, not
the exact moment Flutter painted the image.

Targets 660 and 670 seconds both returned the frame at 658.083 seconds with the
same JPEG size. The second request still spent 976 ms capturing/encoding it.
This is evidence of redundant work across different timestamp cache buckets.
The largest observed distance between requested bucket and decoded keyframe was
11.917 seconds. Pointer-to-image distance can also include bucket quantization.

## Main playback and UI

- Decoder drops: zero throughout; output drops: zero throughout.
- Sampled absolute A/V difference never exceeded approximately 10.7 ms.
- During extraction, maximum sampled Flutter build time was 10.139 ms and raster
  time 8.767 ms. These are separate stage maxima, not presented-frame latency.
- Larger UI timing spikes (58.668 ms build / 73.884 ms raster) occurred at startup
  before the first preview. They should not be attributed to extraction.
- Buffering transitions were confined to startup and the three explicit seeks.
  Final seek-related buffering spans were approximately 0.39 s, 0.63 s and 1.50 s.
  No additional preview-only stall was recorded during ordinary playback.

This establishes observed behavior for one short session, not a guarantee against
stutter on other media/hardware or under different torrent availability.

## Memory and CPU limits

Whole-process RSS peaked at 452.3 MiB during extraction and ended at 229.8 MiB.
Samples immediately before the first preview were 389.5 and 325.9 MiB. These
changing totals include playback, torrent/native caches, JPEG processing and
Flutter; they cannot establish an isolated preview memory cost or a leak.

The external CPU sampler started at 17:07:49, after the last extraction completed
at 17:07:45. Only six samples survived before app shutdown. Consequently there is
NO usable hover/extraction CPU comparison from this session. The recorded tail
must not be used to claim a preview CPU percentage. Future runs must attach the
CPU sampler before permitting interaction, or collect CPU in the app sampler.

## Confirmed native capture defect

The application calls MediaKit NativePlayer.setProperty('vf', filterString).
Inspection of media_kit 1.2.6 shows this wrapper calls mpv_set_property_string but
ignores its integer return code. In a small C probe linked against the exact
Profile app's Mpv.framework, the same vf setter returned:

```text
vf set result: -9 (unsupported format for accessing property)
vf readback:
screenshot result: 0
w: 1920
h: 1080
```

The probe used the repository's complete H.264 fixture and the same null output,
paused video, filter expression and screenshot-raw/video command. This directly
establishes rejected filter configuration and unscaled capture in that reproduction.
The live session did not record screenshot dimensions, so attributing its large
JPEGs to the same defect is a strong inference, supported by the identical code
path and packaged runtime. MediaKit's default JPEG capture copies BGRA pixels
into a Dart image and encodes JPEG in a worker isolate: larger captures increase
both temporary allocations and encode work.

The earlier fast keyframe benchmark used Homebrew mpv 0.41, which accepted the
configuration. Those timings did not establish packaged-library capture behavior.

## Recommended order

1. Configure resizing through an API supported by the packaged runtime, check
   errors and verify actual output dimensions before encoding. If its filter
   path cannot scale, downsample raw pixels before JPEG encoding instead.
2. Reuse an already-captured keyframe when a new bucket resolves to that frame;
   avoid encoding the same picture again.
3. Repeat the live profile audit with CPU recording active from startup, image
   dimensions included and separate uncached/cached test periods.

No production fixes were made while analyzing this recording.

## Artifacts and native reproduction

`events.json`: this process's structured in-app records.
`cpu.jsonl`: late CPU/RSS tail, excluded from performance conclusions.
`capture_probe.c`: minimal packaged-runtime capture reproduction.

From the repository root:

```sh
clang -I/opt/homebrew/include tool/preview_audit/live_2026-10-24/capture_probe.c -F "$PWD/build/macos/Build/Products/Profile/Sentorr.app/Contents/Frameworks" -framework Mpv -Wl,-rpath,"$PWD/build/macos/Build/Products/Profile/Sentorr.app/Contents/Frameworks" -o /tmp/sentorr-capture-probe
/tmp/sentorr-capture-probe "$PWD/tool/codec_lab/assets/media/bbb_h264.mp4"
```

## Compatible filter follow-up

Checking the version-pinned mpv 0.36 documentation and testing the packaged
framework narrowed the diagnosis: string property setters are supported. The
original expression was rejected; wrapping a named FFmpeg graph in `lavfi=[...]`
was accepted, but playback then failed with `No such filter: 'scale'`. Thus this
build lacks that FFmpeg filter; changing the setter representation alone cannot
make the original chain work.

A working alternative is mpv's built-in `format` conversion filter:

```dart
await native.setProperty('vf', 'format=w=240:h=136:convert=yes');
// Or: await native.command(['vf', 'set', 'format=w=240:h=136:convert=yes']);
```

Native probes linked to the packaged Mpv.framework returned success and actual
240×136 screenshot-raw dimensions for H.264 (property setter) and Main10 HEVC
(command API). Width and height here are test values: production should calculate
them from the source aspect ratio and enforce the thumbnail bounds. Neither the
application filter nor runtime behavior has been changed by this lookup.

Version-pinned sources:
- https://github.com/mpv-player/mpv/blob/v0.36.0/DOCS/man/vf.rst (`format`, `w`, `h`, `convert`)
- https://github.com/mpv-player/mpv/blob/v0.36.0/DOCS/man/input.rst (`vf set`)
