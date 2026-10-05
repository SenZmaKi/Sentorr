# State and cross-device sync audit

Audited 5 October 2026. Scope: watch/follow state, local persistence, LAN
exchange, pairing lifecycle, peer libraries/copies, and Drive backup sync.
The findings and line references below describe the pre-fix audit. No browser
inspection or physical-device testing was performed.

## Resolution

Implemented fixes for all nine findings and the additional scheduling and
reachability observations:

- Original follow contributions survive intermediate merges and are filtered
  by tombstones, including all three-device permutations and groupings.
- Drive publishes immutable snapshots and compacts only ids already read;
  concurrent publishers and initial creators retain each other's updates.
- Copy partials are bound to source content versions and release metadata;
  stale offers are rejected by the source and ranges validated by the copier.
- Logical revisions order watch/follow state, notification choices and removals,
  independently of device clock skew. Concurrent ties resolve deterministically;
  wall timestamps are retained for display/90-day retention. Version-one records
  use timestamp fallback until updated; historical mistakes cannot be inferred
  retroactively from legacy data.
- Full-content/canonical comparisons prevent false equality and rewrite loops.
- Pairing and library request generations invalidate late results; polls are
  serialized and old failures cannot override a successful sync.
- Dirty playback and requests during backup trigger follow-up publication;
  pending LAN syncs keep the earliest deadline and discovery loss marks offline.

Formats now emit version 2 and still read version 1. Update participating devices
together; old builds refuse the new format rather than silently dropping its
causal and contribution metadata. See ARCHITECTURE.md for the resulting contract.
Regression coverage lives in `test/sync/state_merge_test.dart`,
`test/sync/peers_race_test.dart`, `test/sync/copy_test.dart`,
`test/backup/drive_test.dart`, and `test/backup/sync_test.dart`.

## Post-fix validation

- Full `flutter test`: **629 passed**.
- After adding the final copy source-version check, reran
  `flutter test test/sync/copy_test.dart test/sync/transport_test.dart`:
  **10 passed**.
- `flutter analyze --no-pub`: no issues.
- `git diff --check`: clean.
- Live Google Drive and separate physical-device testing remain unverified.
  Provider tests exercise the actual Drive client through HTTP adapters;
  LAN tests exercise pinned HTTPS and byte ranges on loopback devices.

## Original audit validation

- All 72 existing tests passed: `flutter test test/sync test/backup test/following/snapshot_test.dart test/following/notifier_test.dart test/watching/history_test.dart`.
- Four temporary Flutter probes reproduced the timestamp-tie, equality,
  unfollow/refollow merge-grouping, and future-clock behaviors below. They
  asserted the observed bugs, so passing probes demonstrate reproduction,
  not correctness. Probe source is `/tmp/sentorr-sync-audit/audit_probe_test.dart`.
- Remaining findings are code-path/race analysis, not exercised against live
  Google Drive or separate physical devices.

## Findings

### 1. P1: An unfollowed record contributes obsolete progress after refollow

`lib/following/snapshot.dart:33–43,78–100`

Records are combined before the removal timestamp is applied. A stale record
can therefore contribute its higher episode to a newer record that survives
an unfollow. Reproduced with A holding episode 10 at t1, B unfollowing at t2,
and C following/watching episode 2 at t3. `(A merge B) merge C` yields episode
2, while `A merge (B merge C)` yields episode 10. A later sync can spread the
obsolete episode 10 again, suppressing release alerts and automatic downloads.

Filter records invalidated by the combined tombstone before merging their
fields. Test three-device grouping and repeated exchanges.

### 2. P1: Concurrent Drive writes can overwrite state without a conflict

`lib/backup/drive/drive_client.dart:39–50`

The revision is checked by a separate list request, then PATCH is unconditional.
Two devices can both see the same checksum and pass the check before either
writes. The second write overwrites the first; both report success and neither
retries. The displaced records may recover if their originating device syncs
again, but are absent from the backup meanwhile. Initial creation also permits
duplicate files; choosing the oldest does not merge records in the others.

Use a provider-supported atomic conditional-write mechanism, or redesign the
backup as per-device records that are merged without overwriting each other.
Exercise simultaneous writes against the actual transport adapter; current
conflict tests cover a changed revision before the check only.

### 3. P1: Resumed copies can silently combine different releases

`lib/sync/copies.dart:57–66,100–110,121–148,191`
`lib/library/layout.dart:13–36`

The partial filename depends on title/episode and extension, not source content.
After an interrupted copy of release A, retrying from a peer offering release B
with the same extension appends B at A's existing offset. The only final check
is total length. It can succeed with a mixed, corrupt file and store B's release
metadata. A peer replacing its file during a retry has the same issue.

Bind partial files and range requests to an immutable content identity
(torrent/file identity plus a server-enforced version), restarting on mismatch.
Validate the returned range and final content identity.

### 4. P2: Equal timestamps do not have deterministic conflict resolution

`lib/backup/watch_backup.dart:41–49,54–65`
`lib/following/snapshot.dart:78–106`

Watch merge keeps the local entry on a timestamp tie. Follow merge keeps local
notification preferences on a tie, and local `manual` on equal episode/progress.
Reproduced opposite merge orders retaining different positions and notification
choices. A serialized single-direction exchange may settle some follow ties,
but simultaneous exchanges have no stable winner. Watch `matches` compares only
id and timestamp, so it calls different tied positions equal and skips saving
or uploading a correction.

Define a deterministic total ordering for shared records/fields and compare
complete shared content. Give equal-time list entries a stable id tie-break.

### 5. P2: Clock skew can erase newer progress or defeat removals

`lib/backup/watch_backup.dart:32–49`
`lib/following/snapshot.dart:25–43,83–89`

Every winner and deletion decision uses device wall-clock timestamps without
causal ordering or skew handling. Reproduced a device one hour ahead retaining
10-minute progress over another device's later real-world 30-minute progress.
The same skew can resurrect a deleted item or keep it deleted after it is watched
again. Clock-dependent tombstone expiration compounds this near the 90-day cutoff.

Use logical/causal versions with device identifiers, and explicitly define the
wall-clock retention policy separately from conflict ordering.

### 6. P2: Late requests can change state after unpairing

`lib/sync/service.dart:105–110`
`lib/sync/client.dart:147–148`
`lib/sync/peers.dart:152–178,188–203,254`

Unpair removes the displayed peer and closes its client without force, but does
not invalidate in-flight operations. An already accepted incoming request, or
an outgoing response arriving after unpair, can still merge watch/follow state
and recreate its peer status. `_syncOnce` does not recheck pairing after await.

Invalidate requests using a pairing generation and recheck it before merging
or publishing results. Cancel active requests where possible.

### 7. P2: Library refresh responses can overwrite newer snapshots

`lib/sync/peers.dart:208–229`

Five-second polls have no per-peer in-flight lock despite a call taking up to
40 seconds across its two timeout stages. Slow polls can overlap and return out
of order. The check for a running sync catches only one still running when the
poll returns; it misses a newer sync that already completed. Old progress,
removed files, or unfinished status can overwrite a newer library. Errors from
old polls can also mark a recently successful peer offline.

Serialize refreshes or tag every library update with a request generation and
ignore stale results and failures.

### 8. P2: Equivalent follow snapshots can cause repeated Drive uploads

`lib/following/snapshot.dart:27–32,48–56`
`lib/backup/backup_bundle.dart:19–34`

Equality uses JSON text, including insertion order of the removal map. Two
devices with the same removals inserted in different orders preserve their
own order during merges and compare unequal. They can keep rewriting the
same semantic state in Drive. Equal watch timestamps can similarly produce
unstable series ordering.

Compare maps by keys/values or canonicalize shared serialization and list order.

### 9. P2: Switching devices soon after a Drive sync can miss new playback

`lib/backup/notifier.dart:111–119,198–200,214–218`

Lifecycle sync is gated only by the last successful sync age, not by local
changes. Watching after a recent sync and backgrounding within ten minutes
skips uploading that new progress. A second device restoring/syncing from Drive
then sees the previous position. A sync requested while busy is also dropped
rather than queued, including changes made after the current upload snapshot.
LAN sync may cover this on the same network; it does not solve an away-from-home
Drive handoff.

Track dirty state and queue one follow-up sync; push dirty playback state on
background transitions irrespective of the last successful sync age.

## Additional scheduling/reachability observations

- `lib/sync/peers.dart:102–106` cancels every pending deadline. A watch change
  can postpone a two-second library sync to ten seconds, contradicting the
  documented earliest-deadline behavior. Repeated faster-than-ten-second
  changes defer sync until the heartbeat. Normal playback records every
  fifteen seconds, so it does not ordinarily starve this timer.
- Discovery disappearance does not mark peers offline, and already-online
  peers ignore `found`. A sleeping peer or one moving addresses can look
  reachable until a request fails or the three-minute heartbeat runs.
- Tombstones intentionally expire after ninety days. An older device or backup
  can resurrect removed records after that period; this is a documented limit,
  not an unexpected implementation defect.

## Recommended order

Fix removal-before-merge semantics, content-bound copy resumption, and Drive
write races first. Then establish deterministic conflict ordering and equality,
request generations for unpair/refresh races, and dirty-state handoff scheduling.
Keep regression tests for three-device permutations, timestamp ties, clock skew,
simultaneous writes, changed copy sources, unpair during I/O, and out-of-order
library responses.
