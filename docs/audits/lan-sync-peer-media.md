# LAN pairing, sync and peer media audit

> Repair update (22 October 2026): the recorded findings have implementation
> fixes in [the repair report](fixes-2026-10-22.md). This document preserves
> the original audit evidence and its validation limits.

Date: 22 October 2026. Checkpoint 7 of the critical-module sanity checks.
Reviewed HEAD: `b5eb59e5dba164a03a3951bc1a2fb8b6c77117cf`.

Status: audit complete; three findings remain open. No production code changed.

## Scope and validation

Reviewed pairing and certificate trust, protocol compatibility, unpairing,
state exchange, peer request generations, library discovery, resumable copies,
finished-file serving, buffered torrent serving, and peer disappearance.

Command:

```sh
flutter test --no-pub --concurrency=1 --reporter expanded test/sync test/shared/state_clock_test.dart
```

All 72 existing tests passed, with no skips. Three additional diagnostic cases
reproduced the findings below. Passing diagnostic cases assert the observed
failure behavior; they do not mean the defects have been fixed.

Disposable probes and logs are under `/tmp/sentorr-sanity-7/`:

- `tests.log`: existing suite output.
- `trust_probes_test.dart`, `harness.dart`, `trust-probes.log`: two real TLS probes.
- `copy_probe_test.dart`, `copy-probe.log`: cancellation/replacement probe.

## S7-01 — High: failed pairing persistence leaves the device authorized

Sources: `lib/sync/service.dart:107`, `lib/sync/devices.dart:96`, and the
pairing completion/error handling in `lib/sync/pairing.dart`.

`SyncService.addPaired` trusts the certificate before awaiting the device
repository write. `DevicesNotifier._commit` publishes the new paired-device
state before saving it. A save failure reaches the pairing failure UI without
rolling back either the in-memory device record or trust.

Reproduction used the normal loopback pairing protocol and confirmations on
both sides, with a host repository that throws `FileSystemException` on save.
The host ended in `PairingFailed`, but its paired-device map still contained
the joiner. The joiner's pinned TLS request to `/v1/library` returned HTTP 200.

This is inconsistent authorization after a reported pairing failure. It does
not demonstrate access by a stranger who bypassed pairing confirmation. The
probe established current-process access; restart behavior was not tested.

Fix direction: make durable pairing and authorization one consistent operation,
or roll back the in-memory authorization record when persistence fails. Add a
regression covering the failed UI state, paired-device map and authenticated
request together.

## S7-02 — High: canceled copy can consume a replacement request

Sources: `lib/sync/copies.dart`, especially `start`, `cancel`, `_wanted`, and
`_copy`'s unconditional `finally` cleanup.

Copy ownership is keyed only by item ID. Cancel removes that ID's progress
marker, but does not abort the pending request. Starting another copy for the
same item reinstates a marker that the old attempt treats as its own. The old
attempt can publish its file and then clear the replacement's marker; the
queued replacement exits because it is no longer wanted.

Reproduction:

1. Start a copy of source version `old` and hold its pending GET.
2. Cancel it and request the same item from version `new`, with a different
   torrent release identity.
3. Release the old request and drain the copy queue.

The library received the old release and bytes `[1, 1, 1, 1]`. Only version
`old` was requested; the replacement never fetched its file. This used the
production copy/provider code with a gated peer-client transport seam and real
loopback HTTP file responses. It was not a TLS or native-torrent integration
probe, and does not imply an untrusted-source attack.

Fix direction: give each attempt a generation or cancellation token, validate
it across awaits, and scope cleanup to the owning attempt. Abort canceled
network operations where possible. Regress immediate same-item retry with a
changed source/version.

## S7-03 — Medium: unpairing during file lookup does not revoke that request

Source: `lib/sync/server.dart`, the `/v1/media/:id` route. It authorizes the
certificate, obtains a file, awaits `file.exists()`, then calls `sendFile`
without revalidating pairing. The library route already rechecks authorization
after its asynchronous lookup.

A real TLS server/client probe gated the file-existence lookup to model a slow
filesystem. After the request passed its initial authorization, the probe
removed authorization while lookup was pending, then released the lookup.
The in-flight request returned HTTP 200 and the full fixture file. A subsequent
new request was correctly refused.

The gap is revocation of an already-authorized request that has not begun
serving its file. It is not continued authorization for new requests, nor a
claim that bytes already delivered can be recalled.

Fix direction: revalidate the pairing generation/fingerprint after asynchronous
media preparation and before serving. If immediate revocation must also stop
active transfers, track and cancel those transfers on unpair. Add a regression
for revocation at this boundary.

## Existing protections exercised

- Pinned TLS identities, paired-certificate request authorization, pairing
  confirmation and protocol/channel compatibility refusal.
- Validation of exchange containers before merging, logical-clock retention,
  deterministic state merges and invalidation during asynchronous work.
- Peer request generations that discard stale library/poll results after
  unpairing or newer requests.
- Copy partial metadata bound to device, source version, size and release/file
  identity; ETag, Content-Range and final conditional HEAD checks before publish.
  File versions derive from filesystem metadata; this is not content hashing.
- Independent buffered-torrent leases, verified-byte serving, expiry and
  lifecycle cleanup using synthetic native loopback fixtures.
- Peer reachability, bounded shared-library filesystem work and playback
  fallback behavior covered by the existing focused suite.

## Boundaries and next step

These checks used isolated loopback devices and disposable files. No browser
inspection, app UI launch, normal user data mutation, or public-swarm validation
was performed. Physical-device LAN/mDNS discovery, long-duration transfers and
Android/Windows/Linux behavior remain unverified. Existing tests and synthetic
native fixtures do not establish those integration outcomes.

Earlier checkpoint findings remain open. Next: backup, import/export and
Google Drive (checkpoint 8).
