# macOS hot restart regression

From the repository root, run `python3 tool/player/hot_restart_smoke.py`.
It serves the codec lab's H.264 fixture over loopback HTTP, launches the
production macOS runner with a hidden video window, and sends three real
Flutter hot restarts. Each cycle must decode nonzero video dimensions and
advance playback by two seconds. A crash, lost connection or timeout fails.

The player registers its mpv handle with the runner in debug macOS builds.
The runner clears mpv's Dart wakeup callback in `onPreEngineRestart`, before
Dart destroys its native trampoline. Normal disposal unregisters the handle
after MediaKit has detached the callback. Release builds skip registration.
Native runner changes require a full rebuild/relaunch before testing.

Run `python3 tool/player/hot_restart_smoke.py --shutdown` to check application
exit during active native video playback. It uses the production runtime's
player cleanup registry and exits as soon as shutdown completes. The runtime
awaits registered players before closing torrent services or destroying Dart
callbacks; UI disposal and application shutdown share each player's cleanup
future.

Validation on 2026-10-05: hidden macOS playback decoded 1920px video,
advanced two seconds, completed `AppRuntime.dispose()`, and exited cleanly.
This checks native callback cleanup at application exit using loopback video;
it does not reproduce the original torrent swarm. The player/UI suite passed
72 tests, the focused lifecycle run passed 9, and analysis was clean.

The upstream cleanup fix in media-kit PR #1416 clears callbacks when the new
Dart isolate initializes. Testing on Flutter 3.47.1/macOS showed that alone
still crashes when active playback emits events earlier during restart;
Sentorr therefore detaches callbacks at the native pre-restart boundary.

Validation on 2026-10-03 (macOS 27, Flutter 3.47.1): published MediaKit 1.2.6
crashed on the first restart without the guard. With the guard and the same
published dependency, all three restarts decoded 1920px video and advanced
playback. Player analysis and 33 player/domain/widget tests passed.
