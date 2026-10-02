# IMDb backend map for Sentorr

Research snapshot: 2026-10-02. Implementation now exists; see [README](README.md). This is a proposed domain boundary based on
verified native queries, not a completed feature migration.

Read [catalog shapes](imdb-catalog-shapes.md) and
[title entities](imdb-title-entities.md) for query selections, evidence and
limitations. Successful request/response examples are under `imdb-research/`.
[Hash research](imdb-hash-refresh-research.md) explains why owned full queries
are the default.

## Application contracts

| Domain contract | Contents | Provider source |
| --- | --- | --- |
| TitleSummary | ID, title, type ID/label, poster, years, rating/count, plot, genres, runtime seconds | Shared Title selection |
| TitleDetails | Summary plus original title, partial release date, content certificate, initial credits, recommendations and video metadata | `title(id:)` |
| SeriesDetails | TitleDetails plus available season numbers and episode count | `title.episodes` |
| EpisodeSummary | TitleSummary plus parent series/season/episode identity when available and partial release date | Title plus `series.episodeNumber` |
| Credit | Person ID/name/image, category ID/label, optional character names | Polymorphic credit node; Cast-specific selection |
| Review | ID, author display name, optional rating, heading/body plain text, submission date, votes and spoiler flag | `title.reviews` |
| Page<T> | Items, optional next cursor, optional total | Connection edges plus pageInfo |
| Image | URL and optional width/height | Image object |
| PartialDate | Optional year/month/day | IMDb release date; incomplete dates remain incomplete |

These are proposed application shapes. Server introspection was denied;
observed JSON does not establish formal schema nullability. Keep optional
metadata optional and check required IDs/connection structures explicitly.
Use provider IDs for identity, not localized labels or title text.

Do not derive `isOngoing` solely from `releaseYear.endYear == null`: upcoming,
missing metadata and other states can share that shape. Treat production state
and popularity fields as separately qualified provider metadata; some verified
responses returned entitlement `DENY` markers for those fields.

## Repository interface

The initial repository can grow into these focused operations:

```text
trendingTitles(limit) -> List<TitleSummary>
searchTitles(filters, cursor, limit) -> Page<TitleSummary>
getTitleDetails(titleId) -> TitleDetails
getEpisodes(seriesId, seasonNumber, cursor, limit) -> Page<EpisodeSummary>
getReviews(titleId, hideSpoilers, cursor, limit) -> Page<Review>
```

Use cancellation throughout. Keep the existing suggestion endpoint as an
explicit autocomplete operation, not a substitute for filtered search.
Do not add fan favorites or personalized recommendations to the guaranteed
public catalog contract yet; the homepage batch required a session ID.
The separately verified `title.moreLikeThisTitles` relationship is a different
recommendation source.

## Request composition

For a detail screen, request the title summary, extra metadata, principal
credits, a small first credit/recommendation page and season numbers together.
For a series, optionally select the first visible episode page in that same
query. The research verified movie and series combined selections through a
single request, eliminating Electron's HTML JSON-LD/Next-data merge.

Fetch later episode and review pages independently. Search cursors are String
variables; episode/review cursors were verified as ID variables. Store all
cursors as opaque Strings in the application and preserve the corresponding
filter/sort request. GraphQL aliases can identify separate collections in one
operation, but each collection keeps its own pagination state.

Combining fields reduces network round trips; it does not remove connection
edges or pagination, and does not guarantee cheaper provider execution. Avoid
fetching every season, all cast, reviews and videos for each search card.
Prefer distinct summary and detail query documents with shared fragments.

## Implementation boundary

Keep code feature-oriented under `lib/imdb/`:

- Owned query documents/fragments for each application operation.
- One small GraphQL transport boundary using injected Dio and the existing
  public headers, timeouts and cancellation.
- Mappers that flatten provider-specific `edges/node` nesting into domain pages.
- Focused models and repository methods; split files before responsibilities
  grow into a large API class.

The application/UI should never need to understand `node.title` versus `node`,
parse provider HTML, or manipulate persisted hashes. Start with full JSON POST
queries. APQ is optional transport optimization, not a discovery requirement.

GraphQL errors require inspection even after HTTP 200. Required-section errors
should fail that operation; partial optional results need an explicit result
contract rather than silently pretending the detail is complete. A 403/empty
202 is an access problem, a schema validation error is a document problem, and
an APQ cache miss is a persisted-document problem. Do not collapse them into an
unbounded retry interceptor.

## Migration sequence

1. Normalize the verified title summary and add filtered search with pagination.
2. Add title details and principal credits using the verified combined selection.
3. Add season-specific episode pages and standalone episode details.
4. Add review pages and bounded recommendations/credits pagination as needed.
5. Connect Riverpod/UI only after these contracts are settled; no UI work is
   included in this research.

Test response mapping with sparse metadata, movie versus series, multiple
credit node types, partial dates, separate cursors and GraphQL partial errors.
Keep live checks explicit and separate from offline tests. No maximum page
sizes, reliable public rate limits or cross-platform behavior were established.
Video URL availability is metadata evidence, not proof of playable formats or
stable playback URLs; follow `tool/codec_lab/` validation for playback claims.

The API response disclaimer and entitlement signals documented in the research
remain applicable. Technical success is not evidence of distribution rights or
a service guarantee.
