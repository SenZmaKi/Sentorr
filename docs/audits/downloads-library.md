# Downloads and local library audit

> Repair update (22 October 2026): the recorded findings have implementation
> fixes in [the repair report](fixes-2026-10-22.md). This document preserves
> the original audit evidence and its validation limits.

Date: 21 October 2026. Source revision:
`b5eb59e5dba164a03a3951bc1a2fb8b6c77117cf`.
Part of [the critical-module sanity checks](../sanity-checks.md), step 4.
Audit complete; findings below remain open. Production code was not changed.

## Scope and validation

Inspected download queue serialization, concurrency limits, preparation attempts,
pause/resume/cancel and batches, progress/completion/seeding, saved-state decoding,
planner handoff, library paths and persistence, offline classification and
file/resume-state deletion. Compared the relevant Senpwai restore implementation,
which validates and isolates damaged saved records rather than trusting casts.

Command:

```sh
flutter test --no-pub --concurrency=1 --reporter expanded \
  test/downloads test/library \
  test/ui/downloads_test.dart test/ui/downloaded_track_test.dart
```

Result: 87 passed, no skips, 29 seconds. Native cases used generated local
torrents and loopback peers. Four temporary fault probes passed assertions of
the observed bad behavior. One further native planner probe reproduced the
handoff timeout and completed the existing download/playback/deletion assertions.

Current coverage verifies:

- Per-download preparation generations reject stale metadata/add results and
  release only their own attempt owners; pending deletion intent survives add.
- Queue ordering, normal slot limits, batched pause/resume/cancel and rejection
  of late jobs after batch cancellation.
- Manual pause survives playback arbitration; parked streams and fully cached
  playback release bandwidth to other downloads.
- Metadata preparation timeout and retries after failed pause/resume commands.
- Sharing limits, upload totals and completion survive restart and engine errors.
- Native packs prepare their selected files, share a torrent with playback,
  download exact bytes under renamed paths and reject escaping selections.
- Planner/native library coverage verifies readable layout, local-file playback,
  sibling file preservation, shared resume-state retention and final cleanup.

## S4-01 — High: one malformed saved queue record blocks startup restoration

Location: `lib/downloads/repository.dart:12`.

Restore casts containers/records directly and resolves status names without a
per-record recovery boundary. A syntactically valid JSON object can pass
`JsonFileStore.read()` but then throw a type/format error in the queue decoder.
The store's JSON-corruption backup recovery is not invoked for this failure.
Bootstrap awaits queue initialization before returning the runtime to `main`.

Reproduced by saving a valid empty queue, then writing
`{"version":3,"items":[42]}` through the same store. The backup remained valid,
but `DownloadRepository.load()` threw `TypeError`. This demonstrates structural
corruption handling; no real user queue or unknown-version migration was tested.

Impact: a damaged record can prevent restoration of all downloads and completion
of application startup. This is a concrete cause for the startup error-path gap
already recorded as S1-03, not a separate startup-screen finding.

Recommended fix: validate the envelope/version and decode records defensively,
preserving rejected records and reporting recovery. Define backup fallback for
structural corruption without silently overwriting unsupported future versions.
Test one damaged record beside healthy downloads and malformed batch fields.

## S4-02 — High: enqueue can reject while its download continues running

Location: `lib/downloads/queue.dart:75`.

`enqueue()` inserts the item and starts `_attach()` before awaiting `_commit()`.
If the save fails, the caller receives an exception and no download id, but
neither the queue item nor its attachment is rolled back. A subsequent successful
attachment commit can persist the job even though enqueue reported failure.

Reproduced with production `DownloadQueue` and the existing fake torrent seam:
initialize normally; inject one `FileSystemException` on the next store write;
enqueue; observe the exception; allow background preparation to finish. The
queue then contained one downloading item, its fake torrent was running, and
reloading the actual queue file returned that item.

Impact: callers can report failure or try another torrent while the rejected
job continues consuming bandwidth/disk. The planner adds the library record
only after enqueue returns an id, so this path can also leave a job without
the intended library registration. The probe established the running/persisted
queue state, not a full planner fallback with multiple native transfers.

Recommended fix: establish durable enqueue before starting work, or roll back
and release the item on persistence failure. Keep the returned id and observable
queue outcome consistent, and test both transient and sustained write failure.

## S4-03 — Medium: completed missing files remain classified as downloaded

Location: `lib/library/notifier.dart:196`.

`offlineStateOf()` checks file existence only when the download history item is
absent. A completed/seeding record, or one with finished bytes, bypasses that
check and returns `Downloaded` even when its file was moved or deleted.

Reproduced with a completed item and a missing path in a disposable directory:
with completion history, classification was `Downloaded`; with the same entry
and no history item, it became `DownloadFailed('The file is missing')`.

Impact: offline UI and downloadable checks can offer a nonexistent download
and block a new request. Offline episode queues can include missing files.
`offlineSourceFor()` separately checks existence before returning `LocalFile`,
so this does not imply that the player blindly opens the missing file.

Recommended fix: reconcile completion with actual file availability regardless
of queue history, using bounded/cached filesystem checks where appropriate.
Test missing files with completed, sharing and history-cleared records.

## S4-04 — Medium: failed deletion forgets the library item and reports success

Locations: `lib/library/notifier.dart:59`, `lib/library/notifier.dart:111`.

`removeAll()` saves the library without the entries before attempting file
deletion. `_delete()` logs and swallows `FileSystemException`, so the caller
receives success even if the file remains and its persisted library entry is gone.

Reproduced on macOS: create a disposable media file, make its parent directory
mode 0500, then remove its library entry. Removal completed successfully;
the file still existed, while both provider state and the saved library were
empty. Permissions were restored and the temporary files removed afterward.

Impact: the file keeps consuming disk while its ordinary library delete/retry
action disappears. No irreversible loss of file contents was demonstrated.

Recommended fix: surface a deletion failure and retain enough persisted state
to retry it. Coordinate queue cancellation and file deletion without claiming
success for an orphaned file; cover partial failure in multi-item removals.

## S4-05 — Medium: planner waits for an owner name the queue no longer uses

Locations: `lib/library/planner.dart:286`, `lib/downloads/attachments.dart:9`.

The planner waits for an exact owner `download:<id>` before releasing its
temporary planning hold. The queue now attaches with the generation-specific
name `download:<id>:<attempt>`, so an existing live download cannot satisfy that
predicate. The wait generally ends at ten seconds, or earlier if the torrent
disappears (the predicate also accepts null).

Reproduced with the existing native episode-planner fixture, enabling indefinite
sharing so the completed torrent remained held. Planning took 10,140 ms. The
expected owner was `download:<id>`; the native engine snapshot contained only
`download:<id>:0`. After the probe, sharing was disabled and the original
download, playback and library-deletion assertions still passed.

Impact: slower live/continuing jobs retain planning state for the timeout even
though attachment already succeeded; serial review/planning can accumulate this
delay. Fast jobs that disappear can hide it in ordinary happy-path tests.

Recommended fix: use an explicit queue attachment acknowledgement or match the
correct attempt identity, retaining generation safety. Add a timing-bounded
handoff test while the download remains active or seeding.

## Limits and evidence

Existing S1 backup/shutdown and S2 storage/re-add findings remain relevant and
open. This pass did not fix them or count them again. No real disk was filled:
the enqueue save failure was injected. File-deletion permission behavior and
native handoff were exercised on macOS only. External-volume disconnects,
power-loss recovery, deletion while another owner actively reads the same file,
and physical Android/Windows/Linux download behavior remain unverified.

No browser inspection, app UI launch or production-data modification was used.
Unrelated existing untracked `docs/Torrent/figures/` content was left untouched.

Temporary evidence under `/tmp/sentorr-sanity-4/`: `tests.log`,
`failure_probes_test.dart`, `failure-probes.log`,
`planner_handoff_probe_test.dart`, and `planner-handoff-probe.log`.
Next audit: torrent discovery and matching (step 5).
