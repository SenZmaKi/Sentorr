# Player lifecycle and recovery audit

> Repair update (22 October 2026): the recorded findings have implementation
> fixes in [the repair report](fixes-2026-10-22.md). This document preserves
> the original audit evidence and its validation limits.

Date: 21 October 2026. Source revision:
`b5eb59e5dba164a03a3951bc1a2fb8b6c77117cf`.
Part of [the critical-module sanity checks](../sanity-checks.md), step 3.
Audit complete; the findings below remain open. No production code changed.

## Scope and checks

Traced launch preparation, cancellation and stale-result guards, torrent/local/
peer source selection, failure switching, renderer readiness, parked sessions,
progress/recovery, next-item preparation, queue transitions, buffering and seek
state, focus handling, and player-page close/completion behavior.

- `flutter test --no-pub --concurrency=1 --reporter expanded test/player`:
  138 passed, no skips, 42 seconds.
- Focused widget/provider suites: 10 passed, no skips, 5 seconds:
  `test/ui/player_view_test.dart`, `player_buffering_test.dart`,
  `pick_up_resume_test.dart`, `player_queue_preview_test.dart`, and
  `player_panel_close_test.dart`.
- Additional temporary probes reproduced all three findings below. The playback/
  warmup probe file pair passed 31 tests, and the progress probe passed 8;
  those totals include copies of existing tests and are not additional unique
  application coverage. The audit cases assert the observed faulty behavior.

## What current coverage establishes

- Superseded peer lookups and parked resumes cannot take over newer playback.
- Obsolete seek preparation cannot seek a replacement playback generation.
- Renderer readiness gates media opening while metadata acquisition can proceed.
- Peer failures can advance through alternate peers and then torrent fallback,
  retaining position. Manual torrent replacements retain playback position.
- Stop/release exceptions in the stream cleanup queue do not skip later steps.
- Repeated Next shares a season-extension operation; Previous and newer sessions
  suppress stale advancement. Offline queue fallback and next-item preparation
  have dedicated tests.
- Pausing, settled seeks and item transitions persist the current item's valid
  progress; teardown awaits outstanding saves. Recovery preserves episode and
  rewind settings and clears on explicit close.
- Native macOS buffering/seek, subtitle toggle, sidecar and prepared-stream
  cases ran in the player suite. Local fixtures/loopback peers verify these
  paths without establishing public-swarm or physical-device behavior.
- Focus-loss behavior respects playback state during loading. Native errors
  during open cannot overwrite the failure with later streaming success.

## S3-01 — High: terminal torrent failure is not propagated to player failure

Location: `lib/player/stream/torrent_playback_loading.dart:152`.

`TorrentStreamSession` translates engine errors into a failed session state.
`_watchTransfer` copies that state into `StreamStatus.transfer` but does not
inspect its failure, change the playback stage, release the source, or invoke
the player failure path. The current fallback path instead waits for an
independent MediaKit error and an idle-player check.

Reproduction using the production session/playback classes and the existing
fake engine/player seam:

1. Start a torrent and reach `StreamStage.streaming`.
2. Emit `TorrentStreamException(workerExited)` on the engine state stream.
3. Drain asynchronous event delivery, without synthesizing a renderer error.
4. Observe `transfer.phase == TorrentStreamPhase.failed`, while playback stage
   remains `StreamStage.streaming` and its problem remains null.

Impact: a known terminal transfer failure has no immediate player-level error
or recovery transition. A stall can remain labelled streaming until MediaKit
independently detects/reports the failure. This probe establishes the missing
transition, not the exact timeout or UI duration on a real killed worker.

Recommended fix: handle terminal session failure once for the current playback
generation, surface the underlying problem, and release/stop safely. Distinguish
a dead shared engine from a source-specific failure before retrying candidates;
retrying torrents on the same failed engine cannot repair a worker exit.

## S3-02 — Medium: late search preparation ignores changed playback eligibility

Locations: `lib/player/next_warmup.dart:47`, `lib/player/next_warmup.dart:80`.

When the queue target stays the same, updates that are paused or outside the
search lead return without clearing or updating `_remaining`. A previously
started search can finish later and call `_prepare()` using the stale near-end
value. It does not recheck the current playing state, position, or availability.

Reproduction:

1. With a ten-minute item at 9:10, begin a gated next-item search.
2. Update the same queue to 0:10, still playing, then resolve that search.
3. Observe one `PreparedStreams.start` call despite 9:50 now remaining.
4. Repeat with a paused update at 9:10: resolving the search also starts
   preparation. Both cases were reproduced.

Impact: next-item metadata acquisition and opening-piece download can start
after rewind or pause based on outdated eligibility, competing for resources
when the next item is no longer imminent.

Recommended fix: maintain current eligibility on every update and recheck it
when the search completes. Ensure pause/seek state reaches the warmup controller;
the engine currently drives it from position/queue events. Cover backward seeks,
pause during search, and a source becoming locally/peer available during search.

## S3-03 — Medium: exact-zero rewind retains the previous watch-progress snapshot

Location: `lib/player/progress_tracker.dart:63`.

`_capture()` excludes zero positions. That protects the last valid position
from teardown resets, but also ignores a deliberate rewind to exactly zero
while the same item is still current and has a valid duration. Subsequent
flushes reuse the previous nonzero `_snapshot`.

Reproduction: play the same item at 20:00 and flush, then emit valid player state
at 0:00 with a one-hour duration, pause, and flush again. The tracker still calls
its save callback with 20:00, although the player position is 0:00 and
`canRecord(item)` remains true.

Impact: closing the player immediately after rewinding to the beginning can
leave the old resume position in watch history. Device-local playback recovery
is a separate store, so this is not a claim that every app relaunch resumes at
the old position. Later positive playback positions replace the stale snapshot.

Recommended fix: distinguish an explicit seek-to-start from stop/disposal's
zero reset. Simply accepting every zero position would regress the existing
last-valid-position protection. Cover both explicit rewind and teardown reset.

## Existing findings and verification limits

S1-02 already records that a checkpoint failure aborts engine/application
disposal and caches the rejected cleanup future. S2-01/S2-03 already record
release/re-add and HTTP bind/close races. These remain relevant player boundaries
and are not counted as new findings here.

No real app quit/relaunch recovery presentation, physical Android/Windows/Linux,
public swarm, long-duration memory/resource test, or visual/audio inspection was
performed. Widget/provider tests are not a physical playback-session smoke test.
No browser inspection was used. Temporary probes did not modify production app
data or replace the normal debug build.

Temporary evidence is under `/tmp/sentorr-sanity-3/`: `player-tests.log`,
`player-ui-tests.log`, `failure-probes.log`, `progress-probe.log`,
`player_failure_probe_test.dart`, `warmup_probe_test.dart`, and
`progress_probe_test.dart`. Probe files remain outside the repository.
