# Sentorr Streaming Lab

A desktop Flutter experiment that plays a selected torrent file through **libtorrent → verified piece reads → localhost HTTP ranges → MediaKit**. The engine and native alert pumps run in a worker isolate; the UI uses Sentorr's existing theme and surfaces.

## Setup and run

Keep `Sentorr` and the modified `libtorrent_dart` checkout beside each other. From this folder:

```sh
python3 tool/build_bindings.py
flutter pub get
python3 tool/prepare_fixtures.py
flutter run -d macos --release
```

Use `-d windows` or `-d linux` on the corresponding host. Native prerequisites are in [libtorrent_dart BUILD.md](../../../libtorrent_dart/docs/BUILD.md). The helper selects the current package version, host and architecture; it disables the optional ccache launcher. Windows requires an MSVC development environment. Linux also requires the MediaKit/libmpv platform dependencies. No Android, iOS or web runner is provided in this first lab.

**Rebuild the bridge before running.** A Dart path dependency selects wrapper source but does not compile C++. An old release binary lacks the new piece-reader symbols. Do not publish these binding changes without matching native artifacts for each supported platform.

Fixtures are generated locally with FFmpeg: 90-second synthetic H.264/AAC videos in faststart MP4, MP4 with its index at the end, and MKV. They are ignored and optional for interactive use. They contain a test pattern and a steady tone, not movie footage.

## Experiments

- **Controlled seed:** select a local media file, including a generated fixture. The lab copies it into a temporary seed folder, hashes it, creates a fresh torrent, and connects a separate downloader to the local seed. Transfer is limited to 256 KiB/s. It never modifies or deletes the original file.
- **Open torrent / Load magnet:** retrieve metadata, choose a media file and press Play selected file. Magnet metadata acquisition and piece reads have bounded timeouts. Availability still depends on the actual swarm.
- Seek with the slider or ±30-second buttons. The slider commits one seek when released. Seeking cancels obsolete HTTP reads; new byte demand drives piece priorities and deadlines.
- Pause playback independently from download. Paused playback may continue filling player/socket buffers; this is not a strict pause of torrent activity.
- **Stall seed / Resume seed:** interrupt the controlled seed and test rebuffering/recovery. Native reconnects are explicit in this controlled mode.
- Export a JSON report with recent native/HTTP/player events, seek targets, transfer counters and current player state. Reports contain source paths/URIs; review them before sharing.
- Stop session before selecting another file. Stop closes playback, HTTP requests and native sessions, then deletes only that session's temporary data.

The diagnostics distinguish downloaded file bytes, HTTP bytes served and the player's buffer endpoint. The piece strip samples at most 128 pieces across the file; it is not an exact availability map or a playable time interval.

## Boundaries

- `lib/engine/native_session.dart`: native lifetime, a single alert consumer and copied piece-read completions.
- `lib/engine/torrent_bytes.dart`: file-offset mapping, verified piece reads and a 24 MiB LRU cache.
- `lib/engine/piece_scheduler.dart`: combines concurrent consumers into byte-budgeted demand windows (16 MiB target); only the current piece is time-critical, and obsolete priorities/deadlines are cancelled.
- `lib/engine/media_server.dart`: loopback-only opaque URL, HEAD, full GET, single HTTP ranges, cancellation and backpressure. GET responses use a detached socket with standard Dart HTTP headers and Connection: close, so client disconnects cancel readers even while pieces are unavailable.
- `lib/engine/lab_session.dart`: metadata, selected file, controlled seed, diagnostics and disposal.
- `lib/runtime/`: isolate commands, MediaKit coordination and smoke checks.

Bytes come through libtorrent's read API, including its partfile storage, rather than reading holes from an unfinished file. HTTP reads wait for piece availability; missing data never becomes zeros or a false EOF. Only demanded windows are prioritized. Completed bytes remain on disk until session disposal; this lab does **not** implement a rolling disk cache, persistence or background service.

Multi-range HTTP headers are ignored with a full 200 response. Malformed ranges are also ignored; valid unsatisfiable ranges receive 416. A transfer failure after response headers aborts the connection and is recorded. Waiting for an unavailable piece times out after 45 seconds; native read completion times out after 15 seconds. Startup metadata/seed verification times out after 60 seconds.

The macOS lab is deliberately **not app-sandboxed** so its CLI smoke tests can read generated fixture paths and write reports. This is a lab runner decision; the production application's entitlements are unchanged. Packaging a sandboxed production player needs its own filesystem-access verification. Abrupt process termination can leave an owned temporary folder; normal Stop/disposal removes it.

## Verification

```sh
flutter analyze
flutter test
dart run tool/native_smoke.dart
flutter build macos --release
"build/macos/Build/Products/Release/Sentorr Streaming Lab.app/Contents/MacOS/Sentorr Streaming Lab" \
  --smoke-test --fixture "$PWD/fixtures/faststart.mp4" \
  --report "$PWD/validation/playback.local.json"
```

Repeat the last command with `tail-index.mp4` and `sample.mkv`. The native HTTP smoke uses deterministic binary data, a real seed/downloader, cross-piece reads, suffix/short-final-piece reads, concurrent distant ranges and seed stall/recovery. Playback smoke checks native decoded video dimensions, playback before completion, forward/backward/repeated seeks and pause/resume. Neither replaces visible frame/audio inspection or validates arbitrary internet swarms.

The binding regression test is also run as an integration test in the sibling repo:

```sh
cd ../../../libtorrent_dart
dart test test/libtorrent_dart_streaming_test.dart integration_test/streaming_test.dart
```

See [VALIDATION.md](VALIDATION.md) for recorded evidence and limits.

## External swarm performance

See [PERFORMANCE.md](PERFORMANCE.md) for the real Pirate Bay audit, measurements,
failures and repeatable native harness. Run `python3 tool/performance_audit.py`
after a release build. Advertised seed counts are not measured connected seeds.

The follow-up [streaming usability audit](USABILITY.md) measures three fresh-cache
runs per playable candidate, two-minute viewing windows, and repeated seeks.
Run `python3 tool/followup_audit.py`, then `python3 tool/summarize_usability.py`.

See [TUNING.md](TUNING.md) for smoothing changes, 5–40 Mbps measurements and
settings recommendations. Audio is muted by default; use the player mute button
to enable it. Download cap and ready-buffer controls apply to the next session.

[WebTorrent source comparison](WEBTORRENT.md) explains scheduling differences,
the recorded startup/probe timeline, and alternatives to pure peer delivery.

## Locked lab baseline

See [FINAL_AUDIT.md](FINAL_AUDIT.md) for the final transport/startup experiments,
measured results and production recommendations. The lab keeps libtorrent and
MediaKit: TCP peer delivery, verified head/tail preparation, a narrow urgent-piece
window, ten seconds of playable ready cache and a 60-second HTTP read timeout are
the audited default policy. The timeout is not a mandatory loading delay.

Experimental environment overrides restore alternatives independently:
`STREAMING_FORCE_TCP=0`, `STREAMING_BOOTSTRAP=0`,
`STREAMING_NARROW_URGENT=0`, and `STREAMING_NETWORK_TIMEOUT=1` (or 5).
The UI's download-cap and ready-buffer controls still apply to the next session.
A weak swarm can remain slow even when the connection cap is 40 Mbps.
