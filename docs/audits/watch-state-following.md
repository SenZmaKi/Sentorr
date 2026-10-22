# Watch state, lists and following audit

> Repair update (22 October 2026): the recorded findings have implementation
> fixes in [the repair report](fixes-2026-10-22.md). This document preserves
> the original audit evidence and its validation limits.

Date: 21 October 2026. Source revision:
`b5eb59e5dba164a03a3951bc1a2fb8b6c77117cf`.
Part of [the critical-module sanity checks](../sanity-checks.md), step 6.
Audit complete; findings below remain open. No production code changed.

## Scope and validation

Inspected progress/completion thresholds and resume behavior, history removals,
list transitions and rewatches, followed progress and season exceptions,
notification/release detection, due episodes, automatic downloads and retention,
and state captured across asynchronous catalog operations.

```sh
flutter test --no-pub --concurrency=1 --reporter expanded \
  test/watching test/lists test/following test/titles/pick_up_test.dart \
  test/home/series_updates_test.dart test/ui/season_watched_button_test.dart \
  test/ui/lists_page_test.dart
```

Result: 83 passed, no skips, 16 seconds. Five temporary diagnostic tests also
passed assertions of the observed faulty behavior described below. These used
production notifiers/controllers with in-memory persistence, gated catalog
responses, paginated catalog fixtures and a recording download-planner fake.
They did not request public metadata or start actual downloads.

Existing coverage establishes:

- Sampling does not create ordinary progress history; resume rewind is bounded.
- Furthest episode selection suppresses older unfinished episodes resurfacing.
- List/history removals retain tombstones; removing list membership suppresses
  pickup prompts while preserving watch history, and new viewing can restore it.
- Whole-series completion paginates aired episodes and excludes future episodes.
- Per-season reset exceptions survive merge independently and do not reset later
  seasons; stale merged state cannot restore superseded season exceptions.
- Normal movie/series list transitions and rewatch handling have fixture coverage.
- Followed-series notification/preferences, static automatic-download settings,
  due episode selection, review dismissal and retention have dedicated tests.
- Release notification filtering and settings, pickup/standing presentation,
  and season controls/list layouts pass their focused suites.

## S6-01 — High: pending automatic work ignores a later per-series Off switch

Location: `lib/following/auto_downloads.dart:113`.

`_run()` captures a `FollowedSeries` before awaiting `dueEpisodes()`. Although
it calls `enabledFor(series)` again in its loop, that reads the current global
setting with the old series object's `autoDownload` value. It does not reread
the current followed record or tracked-list membership.

Reproduced: begin a check for a watched series with auto-download true; gate its
catalog details response; set its switch false through the production notifier;
release the response. The current followed record remained false, but two
automatic `DownloadPlanner.download()` requests were recorded for due episodes.
The planner was a fake: this proves requests after Off, not real native writes.

Impact: a per-series Off change does not revoke pending automatic requests.
Global Off is reread and is a distinct path; this finding does not claim global
Off has the same captured-value bug.

Recommended fix: resolve current tracking/series eligibility before every
automatic action and retention phase, and invalidate or cancel pending planning
when intent changes. Test per-series Off, untracking/unfollow, global Off and
changes during both episode listing and torrent planning.

## S6-02 — Medium: late Completed overwrites a newer manual list choice

Location: `lib/lists/notifier.dart:58`.

Setting a series Completed awaits `completedThrough()` before updating watched
progress and list state. No per-title generation/revision guard verifies that
the viewer still wants that result after the catalog request finishes.

Reproduced: start Completed with a gated title-details response; set the same
series Dropped and await that save; release the older response. The earlier
operation marked the series watched and changed its final list status to
Completed, overwriting the newer Dropped choice.

Impact: slow catalog responses can undo subsequent edits and alter watched
progress under an outdated user request.

Recommended fix: give list operations per-title intent generations and check
them before both followed-progress and list mutations. Preserve latest user
intent across awaits; test newer removal/dropped/watching choices and concurrent
completion requests.

## S6-03 — Medium: a pending Follow can undo a later Unfollow

Location: `lib/following/notifier.dart:111`.

`follow()` awaits the latest episode, then checks only provider lifetime and
whether a followed record already exists. `unfollow()` records a removal but
does not invalidate that pending operation. Its late commit allocates a newer
revision and restores the followed record.

Reproduced through the public notifier: begin Follow and gate catalog details;
await Unfollow; release the details response. The series was present again in
`followedProvider` after Follow completed, despite the newer removal intent.

Impact: opposing actions from different surfaces or delayed follow operations
can restore a series the viewer explicitly removed. Subsequent tracking also
depends on list membership; this probe did not establish a live notification
or automatic download after the restored follow.

Recommended fix: invalidate pending follows on unfollow and compare the captured
intent/removal revision after catalog awaits, before committing a fresh follow.
Keep a genuinely newer explicit Follow allowed.

## S6-04 — Medium: latest-episode and season marking ignore later pages

Locations: `lib/following/latest_episode.dart:65`,
`lib/lists/mark_watched.dart:45`.

`latestEpisode()` fetches one page of 50 episodes per inspected season without
following its cursor. `SeasonMarker.mark()` likewise only examines the first
50. In contrast, `completedThrough()` and `dueEpisodes()` already paginate.

Reproduced with a 60-episode aired season whose first page contained 1–50 and
whose next cursor led to 51–60. `latestEpisode()` returned episode 50 without
requesting the cursor. Marking that running season watched also stopped at 50.
The fixture used a running series so whole-series completion did not mask the
partial season mark by calling the separate paginated completion helper.

Impact: latest-release notifications and followed baselines can lag behind the
real season; season marking can leave the last ten episodes unwatched. An ended
series can also be judged complete against a stale first-page latest episode.
That last consequence follows from the inspected standing/completion consumers;
the probe directly verified latest lookup and season marking.

Recommended fix: share an aired-episode pagination helper for these paths and
test late-page aired episodes, future episodes and metadata with multiple pages.
Use episode numbers/dates rather than assuming totals prove aired coverage.

## S6-05 — Medium: completion-check cache prevents repeated finale completion

Location: `lib/lists/notifier.dart:159`.

`_finishes()` uses `_checked.add(item.id)` to avoid repeated catalog calls.
After any successful lookup, later checks for that item return false rather
than reusing the previous result. The set persists for the notifier's lifetime.

Reproduced: watch an ended series' final episode past 90 percent and confirm
Completed. Open that same episode again and record it past 90 percent. The
list changed to Rewatching on playback, but the cached-id guard prevented it
from returning to Completed. The no-season-exception path was used, matching
ordinary playback-based completion.

Impact: a repeated finale watch in the same app session cannot complete the
series again or advance its completed-rewatch count through this path.

Recommended fix: cache the completion result, or scope/invalidate the check per
playback/rewatch generation instead of returning false for every repeat. Cover
multiple progress saves and a later independent watch of the same finale.

## Evidence and limits

Temporary evidence: `/tmp/sentorr-sanity-6/tests.log`,
`failure_probes_test.dart` and `failure-probes.log`. Five cases passed with
diagnostic output for each reproduction. They assert the current faulty state
and remain outside the repository; fixes should add permanent regressions with
the desired behavior.

No browser inspection, app UI launch, public catalog access, OS notification
delivery, native download or production-state modification was performed.
Snapshot tests are not multi-device LAN/Drive verification; those transports
are upcoming audit steps. Real catalog pagination ordering/availability remains
unverified. Earlier persistence/player/download issues are still open and
were not counted again.

Next audit: LAN pairing, sync and peer media (step 7).
