# IMDb catalog shapes

Verified 2026-10-02 against the unofficial website GraphQL API through native
JSON POST to https://api.graphql.imdb.com/. No cookies, account credentials,
session identifier or browser were used. Public request headers are in
`lib/imdb/website.dart`. This is observed behavior, not a published schema or
availability guarantee.

## Verified operations

| Use | Root selection | Collection path |
| --- | --- | --- |
| Trending | `topMeterTitles(first: Int)` | `edges[].node` |
| Catalog search | `advancedTitleSearch(first:, after:, constraints:, sort:)` | `edges[].node.title` |
| Lightweight autocomplete | Separate suggestion HTTP endpoint | `d[]`, filtered to `tt` IDs |

The checked-in `catalog-search.graphql` and `catalog-filtered-search.graphql`
under `imdb-research/` are successful full query documents. Their variables are
`first: 2`, `term: "matrix"`, and optional `after: String`. The first page returned
The Matrix and The Matrix Reloaded; passing its cursor with unchanged filters
returned The Matrix Resurrections and The Matrix Revolutions. The bounded
filtered request returned four total matches. Evidence is in
`imdb-research/catalog-evidence.json`.

### Search arguments

The original Electron variables are not direct GraphQL field arguments.
The verified current nesting is:

```graphql
advancedTitleSearch(
  first: $first
  after: $after
  constraints: {
    titleTextConstraint: { searchTerm: $term }
    titleTypeConstraint: { anyTitleTypeIds: ["movie", "tvSeries", "tvMiniSeries"] }
    genreConstraint: { allGenreIds: ["Action"] }
    releaseDateConstraint: {
      releaseDateRange: { start: "1990-01-01", end: "2026-10-02" }
    }
    runtimeConstraint: { runtimeRangeMinutes: { min: 60, max: 240 } }
    userRatingsConstraint: {
      aggregateRatingRange: { min: 5, max: 10 }
      ratingsCountRange: { min: 1000 }
    }
  }
  sort: { sortBy: POPULARITY, sortOrder: ASC }
)
```

Omit unwanted constraints. `after` expects a String, not an ID variable.
`POPULARITY`/`ASC` was verified; the rest of Electron's sort enums and result
limits are not exhaustively verified. A genre constraint accepts the label
`"Action"`; do not assume returned opaque `genre.id` values are search labels.

## Shared title summary selection

| Wire path relative to Title | Suggested domain field | Observed representation |
| --- | --- | --- |
| `id` | `id` | `tt`-prefixed String |
| `titleText.text` | `title` | String |
| `titleType.id` | `typeId` | `movie`, `tvSeries`, etc. |
| `titleType.text` | `typeLabel` | Display text |
| `titleType.canHaveEpisodes` | `canHaveEpisodes` | Boolean |
| `primaryImage.url/width/height` | `poster` | URL and integer dimensions |
| `releaseYear.year/endYear` | `releaseYear/endYear` | Integer; endYear can be null |
| `ratingsSummary.aggregateRating/voteCount` | `rating/voteCount` | Numeric rating and integer count |
| `plot.plotText.plainText` | `plot` | String without HTML traversal |
| `runtime.seconds` | `runtimeSeconds` | Integer |
| `titleGenres.genres[].genre.text` | `genres` | List of labels |

These are observed shapes; introspection was denied, so this table does not
claim schema-level non-null guarantees. Treat missing metadata as optional;
reject missing IDs and malformed required structures. Avoid coercing missing
ratings to zero or inferring ongoing status solely from a null end year.

## Pagination and errors

Search returns `total`, `pageInfo.hasNextPage`, `pageInfo.endCursor`, and `edges`.
Keep cursors opaque and associate them with the exact filter/sort request.
Normalize connections into `Page<TitleSummary>` within the IMDb layer; UI code
should receive items and a next cursor, not traverse GraphQL edges.

HTTP 200 can contain GraphQL errors or partial data. A changed schema is not
fixed by retrying a hash. Full query requests have no frontend hash to refresh.
Cancellation and existing network timeouts should remain in effect.

## Source and access limits

Primary source: live responses from https://api.graphql.imdb.com/ using the
checked-in query selections and evidence described above. The consumer
baseline is `Electron/src/backend/imdb/api.ts` and `types.ts`; those files are
product requirements, not proof of the current provider schema.

`__schema` returned HTTP 500 with an unauthorized-introspection error. No
exhaustive field types, enum list, maximum page size, or rate limit was obtained.
Successful search responses also included
`extensions.entitlements.fields["Query.advancedTitleSearch"] = "DENY"`.
Receiving data does not settle the meaning or enforcement of that signal.
Responses carry a data-use disclaimer pointing to
[IMDb's guidance](https://help.imdb.com/article/imdb/general-information/can-i-use-imdb-data-in-my-software/G5JTRESSHJBBHTGX#).
This research establishes technical response shapes, not distribution rights.
