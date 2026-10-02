# Verification

Recorded on 2 October 2026, macOS Apple Silicon. This is a controlled desktop proof, not certification of arbitrary torrents or codecs.

## Passing checks

- `flutter analyze`: no issues.
- `flutter test`: 7 HTTP transport tests passed. Includes full/ranged byte equality, suffix/open-ended/clipped ranges, HEAD without data reads, malformed/unsatisfiable ranges, URL/method rejection, explicit seek cancellation and client disconnect while waiting for missing bytes.
- Local `libtorrent_dart`: analysis passed; 10 tests passed across its existing session suite and the new streaming contract registered in both unit and integration suites. The streaming contract verifies piece layout, the shortened final piece, complete batched read alerts, torrent identity and copied buffer lifetime. Generic session creation settings are verified too.
- Owned native bridge rebuilt for macOS arm64 at package version 1.0.1. It is a modified local checkout; no release was published.
- Native torrent/HTTP proof passed: two actual sessions, hash-verified local seed, cross-piece read, short-final-piece suffix read, concurrent distant reads, unavailable read waiting during seed pause, recovery after resume and temporary-data cleanup. Reads occurred while the file remained incomplete.
- macOS release application built and executed successfully with MediaKit's bundled macOS runtime.
- Faststart MP4, tail-index MP4 and MKV all passed native playback smoke: 640 × 360 decoded video dimensions, advancing playback before completion, forward/backward seeks into incomplete media, repeated seeks, pause and resume.

## Playback evidence

Each fixture is a generated 90-second H.264/AAC test pattern. The controlled transfer limit is 256 KiB/s. Measurements below are single smoke samples, not benchmark averages. Progress latency waits until playback position exceeds one second; seek checks wait for position to advance at least 500 ms beyond the requested target, rather than accepting the seek command's immediate position update.

| Fixture | File downloaded at initial playback | Progress check | Forward seek | Backward seek | Repeated seek sequence |
| --- | ---: | ---: | ---: | ---: | ---: |
| Faststart MP4 | 2.62% | 3.77 s | 2.95 s | 4.17 s | 4.41 s |
| Tail-index MP4 | 5.46% | 5.69 s | 2.75 s | 2.24 s | 6.13 s |
| MKV | 2.52% | 3.76 s | 3.66 s | 3.46 s | 4.82 s |

The raw reports also capture actual HTTP byte offsets after seeks. Download totals, player buffer endpoints and HTTP bytes served are separate counters. The seed stall/recovery check is independent of the playback matrix; recovery can include libtorrent peer reconnect delay.

See [results.json](validation/results.json) for the saved summary, precise checks and native artifact hash. Full local reports are ignored as `validation/*.local.json` because they contain source paths and network/runtime details.

## Limits and follow-up

- No browser inspection, visible-frame inspection or audible-quality assessment was performed. Native decoded dimensions and clock advancement do not establish rendering quality, A/V sync or sustained frame pacing.
- No internet swarm or magnet-discovery test was performed. The external torrent/magnet controls are implemented, but their real-network behavior remains unverified.
- Windows and Linux runners exist; they were not built or run here. Their native bridge binaries must be rebuilt before use. No Android/iOS/web runner is included.
- The controlled proof uses single-file torrents; multi-file selection is implemented but a full multi-file/v1/v2/hybrid compatibility matrix remains outstanding.
- Disk data is retained until Stop/disposal, with no rolling disk eviction or persistent resume. Abrupt termination may leave a lab-owned temporary directory.
- The macOS lab deliberately disables app sandboxing for fixture/report CLI access. Production sandbox access and background execution need separate validation.
- Native build emitted warnings because the installed Homebrew OpenSSL archive targets a newer macOS version than the bridge's configured deployment minimum. Success on this host does not verify compatibility with older macOS releases. Flutter also emitted third-party Swift Package Manager migration warnings.

The current engine is suitable for inspecting the streaming boundary and gathering further evidence. Seek-window tuning, broader media/swarm coverage and production lifecycle integration remain separate work.

## Final policy audit — 2 October 2026

The final lab policy is recorded in [FINAL_AUDIT.md](FINAL_AUDIT.md) and
[validation/final-summary.json](validation/final-summary.json). `flutter analyze`
reported no issues, all seven HTTP/cancellation tests passed, and the macOS
release build succeeded. The native proof passed with a deterministic 64 MiB +
123-byte fixture, including exact cross-piece/suffix/concurrent reads, a blocked
read during seed interruption, recovery after reconnection, incomplete-file
playback delivery, and cleanup. The larger fixture keeps its stall destination
outside the new prefetch windows.

The native proof uses the actual TCP/narrow/preparation defaults.
`python3 tool/verify_final_default.py` verifies release playback with policy
overrides removed and records the resolved policy in its report. The final
transport matrix had eleven completed TCP playback runs, followed by a passing
actual-default release playback run, and retained all failed
uTP pilot runs. No browser-based or human frame-by-frame verification was used.
