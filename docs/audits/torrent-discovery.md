# Torrent discovery and matching audit

> Repair update (22 October 2026): the recorded findings have implementation
> fixes in [the repair report](fixes-2026-10-22.md). This document preserves
> the original audit evidence and its validation limits.

Date: 21 October 2026. Source revision:
`b5eb59e5dba164a03a3951bc1a2fb8b6c77117cf`.
Part of [the critical-module sanity checks](../sanity-checks.md), step 5.
Audit complete; findings below remain open. No production code changed.

## Scope and validation

Inspected source adapters and HTTP transport, parallel aggregation and failure
diagnostics, cancellation, title/year/language/episode checks, alternate searches
and batch fallback, ranking/preferences, duplicate merging, selected metadata
downloads and content-file choice. Ranking was assessed against existing
size/swarm and season-pack policies, not treated as a throughput guarantee.

```sh
flutter test --no-pub --concurrency=1 --reporter expanded \
  test/torrents test/player/file_choice_test.dart \
  test/player/torrent_lookup_test.dart
```

Result: 157 passed, no skips, 14 seconds. Four temporary diagnostic cases also
passed assertions of the faulty behavior described below. Existing tests cover
adapter responses, malformed/challenge pages, result identity and preference
rejections, fallback search variants, episode/season/series packs, language
checks, duplicate URL/tracker merging, ranking stability, selected metadata byte
limits/cancellation and native expected-hash rejection before storage creation.

### Live search checks

Ran the existing `dart run tool/torrent_sources/probe.dart`, then a separate
Nyaa search with Animation genre eligibility. These use the shared app transport
and default adapter endpoints; they do not load the app's refreshed signed
source-directory overrides or the user's source preferences.

| Source | Query | Observed result |
| --- | --- | --- |
| Pirate Bay | Big Buck Bunny, IMDb tt1254207 | 2 accepted matches, 1265 ms |
| YTS | Same IMDb query | Valid empty result, 1217 ms |
| Bitsearch | Big Buck Bunny | 11 accepted matches, 1698 ms |
| Nyaa | Big Buck Bunny 2008, Animation genre | Adapter failure; HTTP 200 valid empty page on inspection, 1171 ms for adapter attempt |

These observations establish one query per source at audit time, not general
availability or playable torrent metadata. No public torrent transfers started.

## S5-01 — High: non-pack file selection accepts explicit episode contradictions

Location: `lib/player/stream/file_choice.dart:36`.

For a non-pack release with only one video, file selection skips `_plays()`.
With multiple videos it attempts matching, but retains the original pool when
none match unless the release is marked a pack. It therefore treats a filename
explicitly naming a different episode like an opaque filename with no evidence.

Reproduced: the source-name identity check accepts `Show.S01E03.1080p` for
Show S01E03. Its torrent file list contains only `Show.S01E02.1080p.mkv`.
`playableFile(..., pack: false)` selects that wrong-episode file.

Impact: a release with inaccurate listing metadata can play or download another
episode and associate its viewing/progress with the requested item. Correct
info-hash verification establishes torrent identity, not episode identity.

Recommended fix: reject explicit season/episode contradictions even for a
single-file non-pack release, while preserving support for genuinely opaque
filenames such as `video.mkv`. Cover both single-video and multi-video mismatch
cases and keep season/series-pack matching conservative.

## S5-02 — Medium: malformed source data can discard healthy aggregate results

Locations: `lib/torrents/parsing.dart:29`, `lib/torrents/repository.dart:79`.

The repository isolates `DioException` and `SourceException`, but parser failures
such as `FormatException` escape the source task and reject the aggregate
`Future.wait`. A provider-controlled malformed magnet can reach that path.

Reproduced with the existing Bitsearch HTML fixture, replacing its magnet hrefs
with `magnet:?xt=%FF`. URI parsing itself accepts the string; decoding its query
parameters throws invalid-UTF-8 `FormatException`. Searching Bitsearch together
with a healthy fixture source then throws instead of returning the healthy
release plus a Bitsearch failure.

Impact: malformed data from one index can make all results unavailable to the
caller, defeating the intended independent-source failure behavior.

Recommended fix: reject malformed magnet rows locally and convert expected
parser/response-shape failures at the adapter/repository boundary into source
diagnostics. Preserve cancellation propagation and do not blanket-hide unrelated
programming errors. Add mixed healthy/malformed-source aggregation coverage.

## S5-03 — Medium: wrong-hash metadata prevents trying healthy mirrors

Location: `lib/torrents/metadata_fetcher.dart:34`.

The fetcher tries the next URL after transport/size/basic response errors, but
returns the first response bounded by dictionary markers without validating
its torrent identity. The engine correctly rejects an invalid or wrong-hash
response later, after mirror selection has ended. That release's remaining
provider/cache URLs are never tried in this path.

Reproduced using two locally generated real torrents and intercepted HTTP
responses: a release's first URL returned the other torrent, and its second URL
was configured to return the correct bytes. Fetch returned the first payload;
the public engine rejected it against the expected hash, and the recorded URL
requests contained only the first host. The healthy alternate remained unused.

Impact: one stale/misconfigured mirror can make a release fail despite valid
metadata being available at another advertised URL. No wrong content was added
to the engine or written into its media storage by this probe.

Recommended fix: make parse/identity rejection eligible for same-release mirror
fallback before giving up on that release. Keep native calls on their owned
worker; avoid duplicating unsafe native parsing in a UI/network isolate.
Cover corrupt bencode, wrong hash and a valid later mirror.

## S5-04 — Medium: Nyaa treats valid empty results as a failed provider

Location: `lib/torrents/sources/nyaa.dart:60`.

Both the cache-validity predicate and adapter require `table.torrent-list`.
Nyaa's normal empty-results page has no table. It includes the normal search
page title, `No results found`, and `Displaying results 0-0 out of 0 results`.

The live query returned that HTTP 200 page, but the adapter threw
`SourceException('Unrecognized Nyaa search page')`. Inspection of the captured
HTML confirmed zero tables and the normal empty-results markers. Replaying that
captured page through an intercepted response reproduced the same exception.

Impact: no-match results are reported as provider failures and not cached as
valid empty results. With only Nyaa enabled, `allSourcesFailed` becomes true,
which can suppress alternate or batch searches for an eligible animated title.
The live query established the empty-page classification bug; it did not test
a full Nyaa-only episode fallback against the live index.

Recommended fix: recognize a structurally valid empty-results page separately
from access challenges/layout failures, return an empty successful result and
apply the same rule to cache validity. Cover the captured empty page alongside
challenge, malformed and populated-page fixtures.

## Evidence and limits

Temporary files under `/tmp/sentorr-sanity-5/`: `tests.log`,
`live-providers.log`, `live_nyaa.dart`, `live-nyaa.log`, `nyaa_response.dart`,
`nyaa-response.log`, `nyaa-response.html`, `failure_probes_test.dart`, and
`failure-probes.log`. Diagnostic tests assert observed failures and are outside
the repository, ready to turn into regression cases when fixes are implemented.

No browser inspection, app UI launch, production-state modification or public
swarm playback was performed. Live checks do not prove metadata URL reliability
or regional provider availability. Sustained slow-response/body-size stress,
large search concurrency and live alternate/season-pack resolution remain
unverified. Earlier engine/player/download findings remain open.

Next audit: watch state, lists and following (step 6).
