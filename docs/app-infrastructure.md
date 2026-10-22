# Flutter application infrastructure

`lib/main.dart` initializes `AppRuntime` in `lib/app/bootstrap.dart` and mounts
the application. `lib/app/services.dart` exposes owned services through Riverpod
overrides. See the root [build instructions](../README.md#building-from-source)
for platform setup and OAuth configuration.

## Ownership

- `lib/app/`: bootstrap, lifecycle flush and ordered resource disposal.
- `lib/shared/persistence/`: application paths, serialized JSON storage,
  credentials, window state and artwork caching.
- `lib/shared/net/`: shared injectable Dio client, HTTP cache, cancellation and
  request limits; see [networking](network-stack.md).
- `lib/settings/`: persisted preferences and application configuration.
- `lib/imdb/`, `lib/torrents/`: catalog metadata and torrent discovery.
- `lib/downloads/`, `lib/library/`, `lib/player/`: download policy, completed
  media and playback over `packages/torrent_stream/`.
- `lib/watching/`, `lib/following/`, `lib/lists/`: watch progress, release
  tracking and user lists.
- `lib/sync/`, `lib/backup/`: paired-device services and file/Drive backup.
- `lib/ui/`: presentation; shared appearance follows [DESIGN.md](../DESIGN.md).

Repositories persist their own records. Bootstrap owns service wiring and
lifetime; screens consume providers rather than creating parallel network or
native torrent engines. Stable and nightly identities have independent local
storage; see [nightly releases](nightly-releases.md).

## Persistence and shutdown

Settings and user state are separate from disposable HTTP/image caches and
torrent payloads. `JsonFileStore` serializes writes and preserves malformed
files for recovery. Image-cache and HTTP-cache clearing are independent and
must not erase user state.

Lifecycle transitions flush persistence. Orderly desktop exit flushes state
and disposes player, torrent, network and desktop resources. Forced termination
can bypass asynchronous cleanup; recovery is exercised separately from graceful
shutdown. Android download execution uses `lib/downloads/android/`.

## Development and verification

Run `flutter analyze` and the relevant `flutter test` suites. Native runners
must also be built and exercised on their target platforms; Dart tests do not
prove tray availability, OS exit behavior, codec support or background execution.
Use the hidden [player checks](../tool/player/README.md) and
[performance harness](../tool/performance/README.md) for their documented scopes.
The codec and streaming labs are independent diagnostic packages, excluded from
root analysis. Their findings do not establish all production playback paths.

The [audit checklist](sanity-checks.md) and
[repair report](audits/fixes-2026-10-22.md) distinguish historical findings,
automated regression coverage and remaining live/device checks.
