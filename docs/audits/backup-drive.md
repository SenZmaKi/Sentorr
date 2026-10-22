# Backup, import/export and Google Drive audit

> Repair update (22 October 2026): the recorded findings have implementation
> fixes in [the repair report](fixes-2026-10-22.md). This document preserves
> the original audit evidence and its validation limits.

Date: 22 October 2026. Checkpoint 8 of the critical-module sanity checks.
Reviewed HEAD: `b5eb59e5dba164a03a3951bc1a2fb8b6c77117cf`.
Status: audit complete; two medium-priority service findings remain open.
No production code changed.

## Scope and evidence

Reviewed file import/export, legacy and current bundle decoding, strict remote
validation, shared-state capture/merge, Drive snapshot listing/caching,
publication/compaction, retry scheduling, desktop OAuth and Android auth bridge.

```sh
flutter test --no-pub --concurrency=1 --reporter expanded test/backup
```

All 55 existing tests passed, with no skips. Two additional diagnostic tests
reproduced the races below. Their passing assertions describe existing defects,
not fixes. Probes and logs are outside the repository:

- `/tmp/sentorr-sanity-8/tests.log`
- `/tmp/sentorr-sanity-8/auth_probe_test.dart`
- `/tmp/sentorr-sanity-8/sync_probe_test.dart`
- `/tmp/sentorr-sanity-8/probes.log`

## S8-01 — Medium: delayed desktop token grant survives disconnect

Sources: `lib/backup/drive/drive_auth.dart:153`, `:175`, and `:190`.

Desktop disconnect clears tokens and attempts revocation, but does not
invalidate or drain an outstanding token grant. `_grant` installs its response
and saves any returned refresh token without checking that the connection
still owns the operation.

The diagnostic signed in through the real loopback callback, using a mock Dio
adapter for Google's endpoints. It held a refresh response, awaited disconnect,
verified `connected == false`, then released a successful response containing
access and refresh tokens. The old operation restored `connected == true` and
`accessToken()` returned the newly installed access token.

The response explicitly included a refresh token. The test does not establish
that every Google refresh response includes one, nor that Google accepts a token
after successful real revocation. It demonstrates stale local authorization
state and acceptance of delayed tokens. The equivalent Android authorization
path already checks a generation when its response arrives.

Fix direction: invalidate desktop grants on disconnect and check ownership
before installing or persisting tokens. Cover delayed connect and refresh,
including token responses that omit a refresh token, and reconnect races.

## S8-02 — Medium: pending sync applies after disconnect completes

Sources: `lib/backup/notifier.dart:146` and `:184`;
`lib/backup/backup_data.dart` does not pass a connection-validity callback to
`UserStateSync.merge`.

Disconnect stops the repeating timer and clears state, but does not invalidate
an active `_sync`. After a delayed download returns, that run can merge its
bundle, invoke upload and set `lastBackup` on the disconnected state.

The diagnostic used the production notifier, backup adapter and domain merge
code with in-memory repositories and a gated fake remote. It held a download
containing `tt9`, awaited disconnect and verified empty local history. Releasing
the download then added `tt9`, invoked one upload and set `lastBackup`.

The fake remote intentionally does not enforce OAuth. The upload assertion
establishes invocation after disconnect, not a successful write to Google.
The local history merge is independently reproduced.

Fix direction: bind sync runs to a connection generation and validate it after
network awaits, between domain writes and before upload/status updates. Decide
whether disconnect drains or cancels current work, and regress that contract.

### Reachability qualification for both findings

The current Backup settings UI disables Disconnect while `backup.busy` is true.
These probes call the service APIs directly and establish missing service-level
invariants; they do not demonstrate an ordinary settings-button sequence that
bypasses that guard. Both are medium-priority hardening findings on that basis.

## Protections covered by the existing suite

- Current format declarations and unsupported versions fail before exchange;
  strict remote decoding refuses malformed records rather than compacting away
  data that a lenient decoder skipped.
- Legacy history-only and older bundle versions remain readable. Manual import
  intentionally recovers valid records from a partly malformed record set.
- Watch progress, removals, followed series and lists converge across independent
  mock-backed clients; device-local auto-download choices do not cause repeated
  remote rewrites.
- Immutable snapshots publish before deletion of observed predecessors;
  concurrent writers retain each other's unobserved snapshots. Failed uploads,
  stale reads and incompatible snapshots have focused regression coverage.
- Snapshot reads overlap with a four-request bound and checksum caching avoids
  redundant decoding. Stable/nightly legacy names are consolidated.
- PKCE/state callback checks, desktop revoked-access handling and Android
  method-channel permission/cancellation behavior have focused coverage.
- Lifecycle resume pulls and dirty background pushes, coalesced follow-ups and
  no-op stability are covered without launching the app.

## Inspected limits and remaining integration work

Desktop file export writes directly to the selected destination using
`File.writeAsBytes(..., flush: true)`. There is no temporary-file/rename protocol
for protecting a pre-existing export from a failed overwrite. This is a source
inspection risk, not a reproduced disk-full/interruption finding. Native file
picker dialogs, overwrite confirmation and actual failed writes were not
exercised. Imports merge domains sequentially; no cross-repository transaction
or rollback is provided for a persistence failure during application.

No account credentials were read and no real Drive account was accessed.
Google consent, token revocation, app-data permissions, actual Drive API
responses and Android Play services remain externally unverified. Android tests
mock the native bridge; the desktop callback probe uses real loopback HTTP and
mock token endpoints. No browser inspection or app launch was used.

Unrelated player/settings/test edits and figure directories were preserved.
Earlier checkpoint findings remain open. Next: platform integration and updates
(checkpoint 9).
