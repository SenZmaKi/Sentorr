# Whole-app failure journeys audit

> Repair update (22 October 2026): the recorded findings have implementation
> fixes in [the repair report](fixes-2026-10-22.md). This document preserves
> the original audit evidence and its validation limits.

Date: 22 October 2026. Checkpoint 10 of the critical-module sanity checks.
Observed HEAD: `b94188e28ceebcaf82ce5f484e47d215b5a08f22`.
Status: audit complete; S10-01 and prior findings remain open.
Scope: cross-module source tracing, full regression suites and isolated failure
injection through production state adapters. This is not an end-to-end native
application certification.

## S10-01 — High: retry reports successful restore without retrying failed persistence

Sources: `lib/backup/backup_data.dart`, `lib/sync/user_state.dart`, and
`merge`/`_commit` in `lib/watching/notifier.dart:122`,
`lib/following/notifier.dart:273`, `lib/lists/notifier.dart:187`.

Each domain publishes its merged state in memory before its repository write
completes. If that write fails, the in-memory snapshot already matches the
incoming backup. Reapplying the same bundle takes the no-change return path,
skipping the failed write. The shared adapter can then finish the remaining
domains and report success even though one domain was never persisted.

Three diagnostic cases used a real backup adapter, provider container, domain
notifiers, repositories and disposable JSON files. A `JsonFileStore.replace`
subclass rejected the selected domain's first write, then allowed further
writes. The cases selected watch history, followed series and lists in turn:

1. Apply a bundle with one record in each domain; the selected write fails.
2. Retry that identical bundle after the injected failure has cleared.
3. Observe successful completion and all three records in memory.
4. Create fresh repositories over the files, as on restart: the selected
   domain's record is missing, while the other domains load their records.
5. The failed store saw only one write attempt; retry never reached it.

All three probes reproduced the problem. They do not simulate an actual full
disk, process kill or OS restart; durable state was checked with fresh repository
instances. The exception is injected at the real persistence boundary.

This is stronger than the already-inspected absence of a multi-domain restore
transaction: even retrying does not repair the failed domain in this session.
It affects manual restore through `BackupData.apply` and the shared merge
mechanism used by cloud/LAN state. The probes directly exercised backup apply,
not a live Drive or physical-device LAN exchange.

Fix direction: retain dirty/unpersisted state per domain and retry it even when
logical records match, or roll back failed commits so retry cannot mistake
memory for durable state. Preserve ordered writes and newer concurrent intent.
An all-domain transaction is an optional wider design; fixing the false no-op
retry is necessary independently. Regress each domain and verify fresh disk
loads after failure, retry and a later successful edit.

## Cross-module journey assessment

The earlier finding IDs below refer to recorded checkpoint evidence. They were
not all re-injected in this turn; their presence here is an impact map, not a
claim of fresh native reproduction.

| Journey | Evidence and remaining failure |
| --- | --- |
| Recover after corrupt local state | Persistence tests cover serialization/recovery paths; missing-primary and second-read recovery remain open as S1-01. Malformed queue records can still block startup restoration (S4-01), and bootstrap recovery UI/rollback remains limited (S1-03). |
| Start offline and play an existing download | `test/player/offline_queue_test.dart` connects launch/session, failed catalog lookups and library fallback using disposable files. Missing files still have inconsistent downloaded classification (S4-03); filesystem existence does not establish playable media. |
| Peer disappears before playback | `test/sync/peer_playback_test.dart` refreshes/probes offers and excludes failed sources. Native buffered-stream lifecycle tests exercise synthetic loopback leases. Physical peer disappearance and real decoder recovery remain unverified. |
| Fail a torrent during playback | Existing stream and lifecycle suites exercise state/cleanup; terminal engine failure can still leave the player labeled streaming (S3-01). Re-add/release and storage-move races remain S2-01/S2-02. |
| Change intent while work is pending | Existing lifecycle/session/coordinator tests cover cancellation and stale work. Recorded gaps include stale auto-download eligibility, late list/follow writes, peer-copy replacement and disconnect ownership (S6-01/02/03, S7-02, S8-01/02). |
| Restore/sync, fail a write, retry, restart | New S10-01 probes reproduce false success and a missing durable domain across all three shared state domains. |
| Quit while work is active or persistence fails | Termination-channel and lifecycle tests verify selected boundaries. S1-02 still allows a failed checkpoint to strand teardown. Native clean-exit proof is still missing; no safe-shutdown claim follows from unit tests. |
| Prepare update, restart and install | Restoration tests authenticate cached manifest metadata and verify actual bytes. Live install, Sparkle relaunch, platform permissions and release publication remain unverified; platform findings S9-01–04 remain open. |

## Validation record

Full app suite: all 969 tests passed, no skips (5 minutes 26 seconds).
Torrent engine suite: all 91 tests passed, no skips. Both runs ended with
`All tests passed!` and exit code 0; the app runner anomaly recorded at baseline
did not recur. Error-report fixture log messages were expected test input, not
runner failures.
`flutter analyze --no-pub`: passed, no issues.
Three additional persistence-failure/retry diagnostics: passed while asserting
current defective behavior. No production fix was made.

Commands:

```sh
flutter test --no-pub --concurrency=1 --reporter expanded
# In packages/torrent_stream:
dart test --concurrency=1 --reporter expanded
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded /tmp/sentorr-sanity-10/restore_retry_probe_test.dart
```

Logs and the diagnostic source are in `/tmp/sentorr-sanity-10/`.
The analyzer/test evidence applies to the inspected working tree. Concurrent
changes can advance HEAD during long runs; it is not evidence for a future
commit or CI environment. Unrelated work was preserved.

## Repair order after the audit

1. Durable state and shutdown: S10-01, S1-01/02, S4-01/02, S7-01. Make failed
   saves retryable, recoverable and consistent with authorization/runtime state.
2. Torrent and media ownership: S2-01/02/03, S3-01, S7-02/03. Guard attempts,
   native failures, revocation and teardown across asynchronous boundaries.
3. Correct content and explicit user intent: S5-01, S6-01/02/03, S3-02/03,
   S8-01/02. Prevent wrong-episode selection and obsolete operations winning.
4. Remaining library, discovery, pagination, platform and recovery UX findings.
   Validate fixes at their relevant layer, then perform native/device smoke
   journeys before claiming release readiness.

All 33 recorded findings remain open as audit findings: 12 high and 21 medium.
This count includes source-inspected S9-04 and qualified service-level S8
findings, rather than treating every item as a physical-device reproduction.
Before implementation, recheck each against the then-current code and preserve
concurrent changes. No fixes, commits or publication were requested in this pass.
