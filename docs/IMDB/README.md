# IMDb backend

The application backend uses owned full GraphQL documents and injected Dio.
There are no persisted hashes, browser bootstrap, HTML scraping or per-person
photo enrichment requests in application operations. The captured homepage
hash remains only in an explicit historical diagnostic tool.

## Implemented interface

| Method | Result |
| --- | --- |
| `trendingTitles` | Title summaries |
| `searchTitles` | Filtered page with total and opaque cursor |
| `getTitleDetails` | Summary, dates, certificate, credits, recommendations, gallery, seasons, video metadata |
| `getEpisode` | Episode summary and numeric season/episode numbers |
| `getEpisodes` | Season-filtered episode page |
| `getReviews` | Spoiler-filtered plain-text review page |
| `getCredits` | Credit/person page, preserving multiple characters |
| `getRecommendations` | Related title page |
| `getImages` | Image page with dimensions/type |
| `suggestTitles` | Lightweight title autocomplete |

Models are under `lib/imdb/models/`, selections under `lib/imdb/queries/`, wire
normalization in `mappers.dart`, transport/error handling in `client.dart`, and
application methods in `repository.dart`. No UI or Riverpod presentation state
is included yet. Repository/model code stays usable from the future Flutter app.

`ImdbTitleDetails.backdropCandidate` selects a landscape still-frame candidate
at least 1280 pixels wide. It is not a designated backdrop or a spoiler-safe
asset. Movies have an empty season list and nullable episode count. Missing
metadata remains nullable, not a fabricated zero or inferred ongoing state.

Detail requests fetch bounded preview collections together. Later pages remain
separate operations. `ImdbPage` exposes immutable items, nextCursor and optional
total. Keep cursors tied to their filters/sort. The application caps page requests
at 50; this is an application guard, not proof of a provider maximum.

Primary video metadata is preserved; signed playback URLs are intentionally not
cached in details. Video playback and a fresh signed-URL resolver are outside
this catalog slice. Principal credits are featured people rather than complete
cast/crew; general credits use Cast/Crew fragments.

## Usage and checks

```dart
final network = NetworkClient(cacheDirectory: sentorrCacheDirectory);
final repository = ImdbRepository(network.dio);
final filters = ImdbSearchFilters(
  term: 'matrix',
  genres: ['Action'],
  rating: ImdbRange<double>(min: 5, max: 10),
);
final first = await repository.searchTitles(filters);
if (first.nextCursor != null) {
  final next = await repository.searchTitles(filters, cursor: first.nextCursor);
}
final detail = await repository.getTitleDetails('tt0903747');
// Close network at application shutdown, not after each operation.
```

```sh
dart pub get
dart analyze lib test tool/imdb
dart test
dart run tool/imdb/check.dart trending
dart run tool/imdb/check.dart suggest matrix
dart run tool/imdb/check_backend.dart
```

The backend check is an explicit bounded live check and bypasses cache. It
verified trending, two search pages, Matrix/Breaking Bad details, two episode
pages, standalone episode details, two review/credit/image pages and related
titles. The offline tests use stored research evidence and local HTTP servers.

See [network stack](../network-stack.md) for cache/logging/cancellation ownership,
[backend design](imdb-backend-map.md), [catalog research](imdb-catalog-shapes.md),
[entity research](imdb-title-entities.md) and
[hash investigation](imdb-hash-refresh-research.md). The latter documents are
research snapshots; the initial integration probe is retained as history.

## Limits

No fan-favorites/personalized homepage operation is included: the observed
homepage batch required a session ID for those sections. Locale/country headers
currently use US English. Schema validation errors and partial GraphQL errors
fail explicitly; no automatic hash refresh or unbounded retry is performed.

The website API is unofficial, introspection is denied, and schema/availability
can change. Some successful responses include entitlement `DENY` markers and
IMDb's data-use disclaimer, documented in the research. Receiving data is not
proof of distribution rights. Video/codec compatibility, provider rate limits,
Android/Windows behavior and user-network reliability remain unverified.
