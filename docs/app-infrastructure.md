# Flutter application infrastructure

The root package is the production Flutter app. Run `flutter pub get`, then
`flutter run -d macos` (or a Windows, Linux, or Android device). It opens a blank
canvas using Sentorr's light/dark theme; the catalog home page is the next slice.
Flutter 3.47 / Dart 3.13 or later is required. The initial launcher/tray icons are
generated Flutter placeholders, pending Sentorr branding.

## Ownership and startup

`lib/main.dart` calls `AppRuntime.initialize()` in `lib/app/bootstrap.dart`.
Bootstrap creates app paths, logging, settings, artwork cache, and the existing
HTTP client, then prepares desktop windows, launch at login, and tray integration.
Provider overrides in `lib/app/services.dart` expose these instances. The IMDb
repository uses this existing HTTP client; there is no second network stack.
Repositories only persist their records; they do not initialize other services.

The root path is the platform's application support directory plus `SentorrData`.
Settings and state are separate from disposable HTTP and image caches. JSON writes
are serialized, flushed to a temporary file, then renamed over the destination.
Malformed JSON is renamed to a timestamped `.corrupt` file before defaults are
written; filesystem errors propagate instead of resetting valid data.

`settingsProvider` supplies preferences. Save a complete `AppSettings` through
its notifier to persist changes and apply launch-at-login, always-on-top, and
image-cache limits. Theme mode and close-to-tray read the current provider state.
Start-maximized and start-fullscreen take effect on the next launch.

## Artwork and HTTP caching

Use `AppImage` in `lib/ui/components/app_image.dart` for posters/backdrops, or
`imageCacheProvider` to prefetch with the same manager. `AppImageCache` adapts
Senpwai's file-backed metadata, absolute file paths, and least-recently-touched
byte-budget eviction. The default image budget is 100 MiB with a 30-day stale
period. Cleanup is performed by flutter_cache_manager, so this is an eviction
budget rather than a strict instantaneous disk ceiling. Positive byte budgets
are configurable; malformed metadata is preserved and rebuilt.

HTTP responses use `NetworkClient` with `cache/http` storage. Existing per-request
cache policies and GraphQL error protection remain intact. Image-cache clearing
and HTTP-cache clearing are independent. The image cache is disposable and stores
artwork, never application state or torrent payloads.

## Desktop lifecycle

Window bounds are restored only when sufficiently visible on a current display,
and clamped to that display. Normal bounds are saved with a debounce and flushed
before exit; maximized/minimized/fullscreen bounds are not saved as normal bounds.
Show/Hide/Quit tray actions use tray_manager's current native API. Close-to-tray
and launch-at-login default to off. Linux close-to-tray is intentionally disabled:
icon creation cannot establish whether the desktop has a reachable tray host.
Tray failure preserves ordinary window closing.

macOS native channels handle Dock reopening and system quit. Launch at login uses
the built-in ServiceManagement API on macOS 13+; older macOS can run the app but
cannot enable that preference. Windows/Linux use launch_at_startup. Android skips
these desktop integrations. No Android background torrent service is included.

Orderly desktop close/system quit flush settings, window state, and bounded logs,
then dispose network/cache/provider/native resources. Mobile inactive/paused events
flush persistence. Forced process termination cannot guarantee asynchronous cleanup.
Both macOS configurations have outgoing network entitlements; Android's main
manifest has INTERNET permission. Native release signing remains a release task.

## Design and verification

Production theme code lives in `lib/ui/shared/theme/`, with bundled Geist fonts and
license. The shared `surface.dart` renderer consumes depth styles. The standalone
`tool/design_demo` remains an experiment; production does not import its package.
`tool/codec_lab` is likewise an independent package and provides no production player.
Root analysis excludes their separate dependency graphs.

Run `flutter analyze` and `flutter test`. Persistence checks cover queued writes,
corrupt-file preservation, and recovery after failed writes. A loopback HTTP test
checks artwork download paths and cache reuse after manager restart without a server.
Additional checks cover byte-budget eviction order, limit changes, and preservation
of corrupt cache metadata.
The existing IMDb/network tests run under Flutter's test runner as well.

Build each runner on its native host: macOS/Android can be built on this Mac;
Windows and Linux require their own Flutter/native build environments. Linux's
tray dependency requires GTK 3, X11 and Xi development files and a compatible tray
host (GNOME generally requires an AppIndicator extension). Generated native project
files establish targets; they do not constitute runtime validation on every OS.

Verified on 2 October 2026: root `flutter analyze` reports no issues; all 23 tests
pass; macOS debug build succeeds and native launch/quit creates settings, logs,
and window state; Android debug APK builds successfully. Windows/Linux builds
and Android device behavior have not been exercised on this Mac.

## Native runner adaptations from Senpwai

Senpwai commit `6d7719d` (Add window settings) removed Windows' first-frame Show
callback, replaced Linux's first-frame reveal with early window realization, and
added macOS' `hiddenWindowAtLaunch` hook. Sentorr carries these changes so Dart's
window controller restores preferences before showing the window. All platforms reveal
from the post-frame callback in main.dart.

Commit `7292858` (Fix Linux desktop integration) installed a `.desktop` launcher
and matching icon, and set the GTK icon name. Sentorr bundles these with its own
application ID. A Linux package must install the bundled share files into the
user/system desktop and icon directories for shell integration.

Other Senpwai runner changes are feature-specific and deferred: Windows URL
protocol registration and app-links forwarding; Linux deep-link/single-instance
activation; macOS selected-file/Downloads entitlements and Sparkle helper/signing
configuration; Android notification/foreground-service permissions, notification
icons, core-library desugaring, secure-storage backup exclusions, APK installer
provider/channel, and production signing. Senpwai's older Kotlin/Gradle plugin
setup is not copied over the current Flutter-generated Android configuration.
