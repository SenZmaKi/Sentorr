# Download integrity integration checks

Run from the Sentorr root:

```sh
flutter test test/integration --reporter expanded
```

`download_recovery_test.dart` requires macOS, FFmpeg with libx264, and the
existing debug runner's bundled `Mpv.framework` at
`build/macos/Build/Products/Debug/Sentorr.app/Contents/Frameworks/Mpv.framework/Mpv`.
It skips if the macOS runner is unavailable. Check the test output for skips.
The test runs without a window or audio output and uses a generated eight-second
MP4, a loopback torrent seed and an HTTP metadata server. Personal app data and
public torrent services are not used.

The recovery flow uses real MediaKit/libmpv, TorrentPlayback's decoder-error
listener, LibraryIntegrity, the download queue, native libtorrent hashing and
transfer, and the production LocalPlaybackProblem and manual verification sheet.
It corrupts opening, interior and closing data, then requires:

1. Native playback fails and automatic verification offers recovery.
2. The recovery button replaces the library record and invokes playback handoff.
3. The real download queue completes after repairing and verifying the file.
4. The recovered file exactly equals the original fixture.
5. Native playback resumes beyond the saved three-second position and reports
   decoded width, with no remaining corruption error view.
6. Manual verification reports no missing or damaged pieces.
7. Native resources and all isolated files are cleaned up.

`peer_copy_validation_test.dart` pairs real loopback HTTPS sync services and
copies through PeerCopies, using an HTTP metadata server. It covers valid and
damaged payloads online and offline. Online damage must not enter the library;
offline copies must make no metadata requests and follow the trust policy.

These checks do not exercise the complete PlayerPage/navigation shell, visible
video rendering, Android's native libraries/foreground service, public swarm
availability, or physical-device network discovery. Separate widget tests cover
light/dark verification states and late results after navigation. Native integrity
tests cover middle-only damage and reloading renamed-file resume mappings.

## Verified run (2026-11-13, macOS ARM64)

All five integration cases passed. The combined integration, verification UI,
native integrity, download queue, and peer-copy regression run passed 86 tests.
The actual bundled libmpv decoded the repaired fixture beyond the saved position
and reported a decoded width of 320 pixels. Exact recovered bytes matched the
original generated file. No Android device/emulator was attached (`adb devices`
was empty), so Android runtime validation remains outstanding.

The playback failure view now retains its recovery/handoff state until playback
replaces it. Returning from the recovery callback alone is insufficient because
reopening media is asynchronous and a delayed library update must not launch
another verifier against the active recovering torrent.
