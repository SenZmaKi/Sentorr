# Critical module sanity checks

> Repair update (22 October 2026): see [all 33 fixes and current validation](audits/fixes-2026-10-22.md).
> The checkpoint narratives below preserve the original audit results.

Work through one area at a time. For each area, define its guarantees, inspect
implementation and existing coverage, exercise relevant failure cases, record
findings, and verify fixes before moving on. Keep automated, native loopback,
live-service and physical-device evidence distinct.

## Order

- [x] 0. Baseline and test reliability (runner anomaly recorded below)
- [x] 1. Persistence, startup and shutdown (audit complete; repair report linked above)
- [x] 2. Torrent engine and media server (audit complete; repair report linked above)
- [x] 3. Player lifecycle and recovery (audit complete; repair report linked above)
- [x] 4. Downloads and local library (audit complete; repair report linked above)
- [x] 5. Torrent discovery and matching (audit complete; repair report linked above)
- [x] 6. Watch state, lists and following (audit complete; repair report linked above)
- [x] 7. LAN pairing, sync and peer media (audit complete; repair report linked above)
- [x] 8. Backup, import/export and Drive (audit complete; repair report linked above)
- [x] 9. Platform integration and updates (audit complete; repair report linked above)
- [x] 10. Whole-app failure journeys (audit complete; repair report linked above)

## 0. Baseline — 21 October 2026

Source revision: `b5eb59e5dba164a03a3951bc1a2fb8b6c77117cf`.
The checkout was clean before checks. Dependency resolution succeeded for the
app, torrent engine and source-directory signer without changing tracked files.

Environment: macOS, Flutter 3.47.1, Dart 3.13.1. CI pins Flutter 3.47.2 on
Ubuntu; this local run does not establish results for that exact environment.

| Check | Result |
| --- | --- |
| CI formatting command | Passed: 715 files, zero changes |
| `flutter analyze --no-pub` | Passed: no issues |
| Torrent engine `dart analyze` | Passed: no issues |
| Source-directory signer `dart analyze` | Passed: no issues |
| Torrent engine `dart test --concurrency=1 --reporter expanded` | Passed: 91 tests, no skips |
| App `flutter test --no-pub --concurrency=1 --reporter expanded` | Full retry passed: 965 tests, no skips, 4m43s; initial runner error below |

### Initial app runner failure

After 876 passing tests, the runner stopped during
`test/player/torrent_playback_test.dart`, reporting:

```text
Bad state: Cannot close sink while adding stream.
package:stream_channel/src/guarantee_channel.dart 180:7 _GuaranteeSink.close
package:flutter_tools/src/test/flutter_platform.dart 765:43 FlutterPlatform._startTest

One or more uncaught errors occurred shutting down:
  Bad state: Cannot add event while adding stream.
```

The process returned exit code 0 despite an error event and no final success
summary. A zero exit code alone is therefore insufficient evidence of a passing
suite in this environment. The stack identifies a runner channel failure;
its underlying cause is not established.

The affected file passed all 25 tests when rerun alone. The 21 files not reached
by the interrupted run passed all 86 tests in a separate serial run. Neither
follow-up reported skips. A full serial retry subsequently passed all 965 tests
with no skips and exit code 0 in 4m43s. The runner failure did not reproduce in
that retry; retain it as an unresolved intermittent test-infrastructure finding,
not a demonstrated application defect. If it recurs, capture verbose runner
output and compare against CI's pinned Flutter version before attributing cause.

Baseline status: all checks have a successful run, with one observed runner
anomaly. Step 1 findings are recorded below.

### Native prerequisites and verification limits

The built debug runner's `Mpv.framework/Mpv`,
`tool/codec_lab/assets/media/tracks_subtitles.mkv` and
`tool/codec_lab/assets/media/captions.srt` were present. Both conditional native
player tests executed and passed: caption toggling and stalled paused seeking.
Native torrent/download/library tests also ran using local fixtures and peers.

This baseline does not exercise the standalone hidden-window hot-restart or
shutdown scripts, public torrent swarms, physical Android/Windows/Linux devices,
live Google Drive, or separate physical-device LAN behavior. Standalone labs
are excluded by the root analyzer configuration. The scheduled/manual CI
provider probe is deferred to torrent discovery checks (step 5).

### Evidence

Full local logs are under `/tmp/sentorr-baseline-20261021/` (temporary; not
committed): dependency logs, `format.log`, `analyze.log`, `engine-analyze.log`,
`signer-analyze.log`, `engine-tests.log`, `app-tests.log`, `playback-rerun.log`,
`remaining-files.txt`, `remaining-tests.log`, and `app-tests-retry.log`.

## 1. Persistence, startup and shutdown — 21 October 2026

Scope: application initialization, local state repositories, settings writes,
playback checkpoints/progress, lifecycle flushing, native quit approval and
resource disposal. This was an audit; production code was not changed.

### Verified behavior

- The focused suite passed 73 tests with no skips: `test/shared/persistence`,
  `test/settings`, player progress/recovery/lifecycle, download lifecycle/queue,
  and desktop termination/tray tests.
- Existing coverage verifies queued/coalesced writes, newest-snapshot ordering,
  temporary-file cleanup, quarantine of malformed JSON, recovery from a corrupt
  primary, retry after failed writes, lenient settings decoding, paused seeks,
  progress ownership during item changes, and awaiting pending progress saves.
- Recovery keeps the exact episode and position, applies the configured rewind,
  and clears after an explicit close. Bootstrap requests recovery with
  `autoplay: false` and minimizes the player; visual relaunch behavior was not
  exercised here.
- The hidden macOS native shutdown smoke check passed with an isolated temporary
  app-data directory: one mpv image, 1920x1080 video, two seconds of playback,
  `AppRuntime.dispose()` completed and the process exited cleanly. It registers
  a real player with the production lifecycle registry; it does not instantiate
  the normal player provider or validate a real torrent/watch-history relaunch.

### Findings

#### S1-01 — High: backup recovery is lost on the next read

Location: `lib/shared/persistence/json_file_store.dart:23`.

`read()` returns null immediately when the primary is absent, without checking
`.bak`. Corruption recovery itself renames the primary out of the way and
returns the backup without restoring the primary. A second read, including a
later startup when that repository has not saved again, therefore ignores the
same valid backup. Repositories may load defaults or empty history/library/
following state; the device repository may generate a replacement identity.

Reproduced against production `JsonFileStore` using temporary files:

1. Save value 1, then value 2 (backup contains value 1).
2. Delete the primary: read returns null despite the valid backup.
3. Create a corrupt primary: the first read returns value 1.
4. Read again without saving: it returns null.

Recommended fix: try the backup when the primary is missing as well as corrupt;
cover repeated reads and repository restart without an intervening save.

#### S1-02 — High: a checkpoint failure can strand shutdown

Locations: `lib/app/bootstrap.dart:291`, `lib/app/bootstrap.dart:329`,
`lib/player/engine.dart:214`.

Application disposal removes the tray and hides the window before awaiting
`flush()`. A checkpoint write failure rejects that flush before player,
torrent, network or container cleanup runs. `_shutdown` caches the rejected
future, so subsequent calls cannot retry even after the underlying failure is
removed. `_quit` also caches its result. Native termination approval awaits
this cleanup, and the window's close path cannot reach destruction.

The normal player engine has the same structural issue: `beforeDispose`
awaits its checkpoint before subscriptions and the native player are released,
and its disposal future is cached too.

Native failure injection reproduced this during active 1920x1080 video:
the first disposal rejected with the injected `FileSystemException`, and a
registered player-cleanup marker remained false. After removing the failing
checkpoint, a second disposal returned the same error, the marker remained
false, and the checkpoint invocation count remained 1. The probe then exited
its isolated process deliberately; that exit is not successful runtime cleanup.

Recommended fix: preserve/report persistence failures while ensuring independent
cleanup stages still run. Define retry/exit behavior explicitly, and cover a
failed checkpoint and a failed cleanup stage with regression tests.

#### S1-03 — Medium: startup failure has no user-visible recovery path

Locations: `lib/main.dart:9`, `lib/app/bootstrap.dart:92`.

`main()` awaits all initialization before mounting UI or revealing the window.
An initialization exception therefore leaves no startup error/retry screen.
Initialization also has no rollback boundary for services already created if a
later awaited stage fails.

During the first isolated native attempt, deliberately placing app data outside
the macOS app sandbox caused a `PathAccessException` in `AppPaths.initialize`.
The error was logged, but initialization never reached the smoke marker and
the process stayed running until stopped. This was a probe setup error, not a
failure of the normal app-data location; it confirms the early-error path.
Rollback after a later partial initialization was inspected, not runtime-tested.

Recommended fix: mount a minimal startup error/retry surface and unwind already
owned resources on initialization failure; add injected early/late failure tests.

### Durability boundaries

- `JsonFileStore.flushed` means the write queue drained, not that all saves
  succeeded. A probe confirmed it resolves after a failed write; the individual
  `write()` future carries the failure. Do not use `flushed` alone as proof that
  data reached disk.
- Temporary-file writes request flushing and rename over the primary. The
  backup copy and parent directory are not explicitly fsynced. Power-loss
  durability was not established.
- Forced process death may bypass lifecycle callbacks. Exact latest-position
  persistence after force-quit/crash was not tested or promised.
- Physical Android background exit, Windows/Linux native quit, hot restart,
  and real watch-history quit/relaunch remain unverified in this step.

### Evidence and next action

Temporary probes and logs are under `/tmp/sentorr-sanity-1/`:
`focused-tests.log`, `persistence_probe.dart`, `persistence-probe.log`,
`native-shutdown.log`, `native-shutdown-retry.log`, and `native-failure.log`.
The native probe uses `Directory.systemTemp` inside the app sandbox and never
uses the normal Sentorr state directory. The failed initial probe was stopped
before retrying with that sandbox-compatible path.
After the probes, `flutter build macos --debug -t lib/main.dart` passed,
restoring the generated debug app to its normal entry point. Its log is
`restore-debug-build.log`. Only this audit document changed in the checkout.

Resolve S1-01 and S1-02 before advancing to the torrent engine audit; include
S1-03 in startup hardening. Re-run the affected checks after fixes.

The owner subsequently requested the next audit, so step 2 was inspected with
these step 1 findings still open.

## 2. Torrent engine and media server — 21 October 2026

Scope: worker command concurrency, torrent ownership and release, storage moves,
verified-piece reads, HTTP ranges and cancellation, scheduling, retained-byte
restoration and native teardown. The app consumes published `libtorrent_dart`
1.2.0; no sibling dependency or production code was changed.

### Verified behavior

- All 91 torrent engine tests passed with no skips, using
  `dart test --concurrency=1 --reporter expanded`.
- All 11 app integration tests passed with no skips:
  `test/player/session_race_test.dart`,
  `test/player/prepared_stream_native_test.dart`, and
  `test/downloads/native_engine_test.dart`.
- Existing native coverage verifies download/stream ownership sharing,
  per-owner pause/wanted-file behavior, conflicting kept destinations,
  concurrent add promotions, release and temporary-folder cleanup.
- HTTP coverage verifies exact full/range responses across chunk boundaries,
  suffix/open-ended/clipped ranges, HEAD without body reads, unsatisfiable
  ranges, first-chunk delivery before subsequent pieces, cancellation and
  disconnects while waiting for data or serving a body.
- Production byte reads wait for `havePiece` and native piece-read alerts, check
  native piece length, and never read sparse media files directly. Scheduler
  tests cover urgent/background demands and restoring base priorities.
- Native restart tests verify retained bytes without the original seed, including
  legacy partfiles and rejection of corrupt legacy content. Native media-index
  fixtures cover MP4, MKV, WebM, MOV and AVI.
- Worker-exit and paused-observer tests verify pending-operation failure and
  bounded teardown for those scenarios. These passes do not cover the races
  and failed move below.

### Findings

#### S2-01 — High: re-add can race final-owner release and invalidate the replacement

Locations: `packages/torrent_stream/lib/src/engine/core.dart:277`,
`packages/torrent_stream/lib/src/engine/adds.dart:31`.

Final removal deletes the hash from `_torrents` before awaiting resume-file IO,
then removes its native handle. Add operations serialize with other adds for
that hash, but not with removal. A concurrent add can therefore create a new
entry while libtorrent still holds the old torrent. Removing the old native
handle then invalidates the replacement's handle.

Reproduced with local generated metadata, no external peers, cached storage:
add and await metadata; start final-owner release without awaiting it; add the
same metadata for a new owner; await release and request replacement metadata.
The direct-core probe failed 2 of 3 metadata requests with
`invalid prioritize_files arguments`. The public `TorrentEngine` probe also
failed 1 of 3 requests with the same native error wrapped as
`TorrentStreamException(nativeFailure)`. Cleanup logged invalid torrent handles
on those runs. A successful metadata reply alone does not establish that a
replacement remains usable after the asynchronous native removal.

Impact: quickly replacing/reopening a cached torrent during cleanup can break
the new playback/download owner even though its add completed successfully.

Recommended fix: serialize per-hash removal with adds and await a safe native
removal boundary before reuse. Regression coverage should validate the new
owner remains usable after the old release has fully completed.

#### S2-02 — High: failed native storage moves are published as successful

Location: `packages/torrent_stream/lib/src/engine/core.dart:180`.

`moveStorage()` requests an asynchronous native move. `_move()` immediately
updates `entry.savePath` and storage rank, clears temporary-folder ownership,
and publishes success without awaiting the native outcome. Native move-failure
alerts are not used to reject the operation or restore the entry's location.
The same helper is used when adding a higher-ranked storage owner.

Reproduced with a generated torrent containing an existing local file and a
destination directory changed to mode 0500 inside a disposable test root:

- Engine move returned successfully and its snapshot advertised the new path,
  `TorrentStorage.kept`, and no error.
- Native alert reported `storage move failed ... Permission denied`.
- Native handle's save path stayed at the old directory; its status error was
  empty. The old file remained present and the target file did not exist.

Impact: app/library paths and retention policy can disagree with the real disk
location; later resume data may be saved in the advertised directory rather
than alongside the retained media. This probe did not demonstrate data deletion.

Recommended fix: observe native move success/failure before committing path,
storage rank or temporary-folder cleanup. Preserve the old location and surface
the failure when native movement fails. Cover both success and unwritable-target
promotion, including a stream already using the torrent.

#### S2-03 — Medium: close during HTTP bind can leave a live listener

Locations: `packages/torrent_stream/lib/src/engine/media_server.dart:24`,
`packages/torrent_stream/lib/src/engine/media_server.dart:197`,
`packages/torrent_stream/lib/src/engine/stream_host.dart:93`.

`start()` awaits binding before assigning `_server`. If `close()` runs during
that await, it sets `_closed` but has no server to close. Binding then completes
and installs a listener despite the closed state.

Reproduced directly against production `MediaServer`: begin `start()`, await
`close()`, await the start future, then issue GET to its URL. The closed server
still accepted the connection and returned HTTP 404. The probe explicitly
closed it a second time afterward. This shows a listener leak, not exposure of
media bytes.

In stream teardown, the host can already have been removed from the engine's
stream maps before binding completes. The late lifetime check then throws;
the outer close-by-id finds no host to close again.

Recommended fix: make start/close coordinate on the in-flight bind, closing any
late-created server before start settles. Add a close-during-bind regression
and ensure stream cancellation leaves no accepting endpoint.

### Evidence and limits

Temporary scripts and logs: `/tmp/sentorr-sanity-2/engine-tests.log`,
`app-integration-tests.log`, `server_probe.dart`, `server-probe.log`,
`readd_probe.dart`, `readd-probe.log`, `public_readd_probe.dart`,
`public-readd-probe.log`, `move_probe.dart`, and `move-probe.log`.
All probes used disposable local files; directory permissions were restored
before cleanup. No browser inspection or app UI launch was used.

Verified-byte serving and retained-content checks used synthetic loopback
torrents. Public-swarm behavior, long-duration load, real disk-full/disconnection,
and Windows/Linux/Android native behavior were not tested. The move probe used
macOS filesystem permissions; cross-platform failure behavior remains unverified.

Audit status: complete, with S2-01/S2-02/S2-03 open alongside step 1 findings.
The next audit in sequence is player lifecycle and recovery (step 3).

## 3. Player lifecycle and recovery — 21 October 2026

See [the player audit](audits/player-lifecycle.md) for detailed reproductions.
All 138 player tests and 10 focused player UI tests passed with no skips.
Additional probes found three gaps: terminal torrent-session failures remain
labelled streaming (S3-01), late next-item searches can prepare after rewind/
pause (S3-02), and an exact-zero rewind can retain the old watch-progress
snapshot (S3-03). Existing shutdown findings from step 1 remain open and are
not counted again. Production code was not changed.

The next audit in sequence is downloads and local library (step 4).

## 4. Downloads and local library — 21 October 2026

See [the download/library audit](audits/downloads-library.md) for reproductions.
All 87 existing focused tests passed with no skips. Five additional findings
were reproduced: malformed queue records block restoration (S4-01), rejected
enqueue can leave a running persisted job (S4-02), completed missing files stay
classified as downloaded (S4-03), failed deletion loses its library record while
reporting success (S4-04), and planner handoff uses an obsolete owner name and
waits for timeout (S4-05). No production code changed; previous findings remain
open. The next audit is torrent discovery and matching (step 5).

## 5. Torrent discovery and matching — 21 October 2026

See [the discovery/matching audit](audits/torrent-discovery.md) for details.
All 157 focused tests passed with no skips. Four additional findings were
reproduced: explicit wrong-episode content can be selected (S5-01), a malformed
magnet can abort healthy aggregate results (S5-02), wrong-hash metadata stops
mirror fallback early (S5-03), and Nyaa rejects valid empty search pages (S5-04).
Live default-endpoint checks returned Pirate Bay 2 matches, Bitsearch 11, YTS 0;
Nyaa returned a valid empty page that its adapter misclassified as failure.
No production code changed. The next audit is watch state, lists and following
(step 6).

## 6. Watch state, lists and following — 21 October 2026

See [the watch/following audit](audits/watch-state-following.md) for details.
All 83 focused tests passed with no skips. Five diagnostic cases reproduced
stale auto-download eligibility (S6-01), late completion overwriting a newer
list choice (S6-02), late follow undoing unfollow (S6-03), incomplete episode
pagination (S6-04), and cached completion checks preventing repeated finale
completion (S6-05). Production code is unchanged and prior findings remain open.
Next audit: LAN pairing, sync and peer media (step 7).

## 7. LAN pairing, sync and peer media — 22 October 2026

See [the LAN/sync/peer-media audit](audits/lan-sync-peer-media.md) for details.
All 72 focused tests passed with no skips. Three diagnostic cases reproduced
failed pairing persistence leaving active authorization (S7-01), a canceled
copy publishing the old file and suppressing its replacement (S7-02), and an
in-flight media request surviving unpairing during file lookup (S7-03).
Subsequent new media requests were correctly refused. Production code is
unchanged and prior findings remain open. Physical-device LAN behavior remains
unverified. Next audit: backup, import/export and Google Drive (step 8).

## 8. Backup, import/export and Google Drive — 22 October 2026

See [the backup/Drive audit](audits/backup-drive.md) for details and limits.
All 55 existing tests passed with no skips. Two additional diagnostic cases
reproduced desktop token grants restoring authorization after disconnect
(S8-01), and pending sync merging data/invoking upload after disconnect (S8-02).
Both are medium-priority service-level gaps: the current settings UI disables
Disconnect while busy, and the probes do not bypass that guard through the UI.
Actual Google OAuth/Drive, native file pickers and interrupted file overwrites
remain unverified. No production code changed; prior findings remain open.
Next audit: platform integration and updates (step 9).

## 9. Platform integration and updates — 22 October 2026

See [the platform/update audit](audits/platform-updates.md) for evidence.
All 27 focused Flutter tests and both release-tool tests passed. Three mocked
native-boundary probes reproduced stale notification denial (S9-01), missing
notification launch-target capture (S9-02) and tray initialization surviving
disposal (S9-03). Source inspection also confirmed shared stable/nightly startup
registration names on Linux/Windows (S9-04); no real registration was mutated.
All four are medium priority. Production code was not changed by the audit;
concurrent work was preserved. Native installation, live release feeds and
physical OS behavior remain unverified. Next: whole-app failure journeys
(step 10).

## 10. Whole-app failure journeys — 22 October 2026

See [the failure-journey audit](audits/whole-app-failures.md) for the cross-module
assessment and repair order. The full app suite passed all 969 tests, the torrent
engine suite passed all 91 tests, and `flutter analyze --no-pub` found no issues.
No skips or runner failures were reported.

Three additional diagnostic cases reproduced one new high-priority issue
(S10-01): a failed domain write updates memory, then retrying the same restore
reports success without retrying persistence. Fresh repository loads lose the
failed domain. Watch history, followed series and lists each reproduced it.

The planned audit pass is complete. There are 33 recorded open findings:
12 high and 21 medium. Tests passing does not resolve them or establish native
release readiness. Prioritize durable-state recovery/shutdown first, then
native torrent/media ownership, then stale intent and remaining correctness/UX
issues. Recheck findings against current code before implementing fixes.
No production code was changed by this audit; unrelated concurrent work remains
untouched. Physical-device, live-service and real installer journeys remain
unverified as detailed in each checkpoint report.
