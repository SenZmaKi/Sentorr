# IMDb title, episode, credit and review entities

Observed 2026-10-02 against IMDb's first-party `POST https://api.graphql.imdb.com/`, using `lib/imdb/website.dart` public headers, full query documents, and no cookies, session ID, persisted hash or browser. Evidence contains bounded requests (`first: 1` or `2`) and raw responses. These are observed wire shapes, not a published schema contract: introspection returned HTTP 500. Schema-wide nullability, maximum page sizes, rate limits and all enum values remain unverified.

## Combined title details

[Movie request](imdb-research/title-combined-movie.request.json), [movie response](imdb-research/title-combined-movie.response.json), [series request](imdb-research/title-combined-series.request.json), [series response](imdb-research/title-combined-series.response.json) successfully returned details, principal credits, first credit page, related titles, video metadata and seasons/first episodes in one request for `tt0133093` and `tt0903747`. This can replace the two HTML-script extraction paths in `Electron/src/backend/imdb/api.ts::getMediaOrEpisode`.

| Concept | Observed path under `data.title` | Proposed representation |
| --- | --- | --- |
| Identity | `id` | IMDb title ID string |
| Display/original title | `titleText.text`, `originalTitleText.text` | Separate strings |
| Kind | `titleType.{id,text,canHaveEpisodes}` | Stable machine ID plus display label and capability |
| Poster | `primaryImage.{url,width,height}` | Image object; retain dimensions |
| Years | `releaseYear.{year,endYear}` | Nullable end year; movie endYear was null |
| Release date | `releaseDate.{year,month,day}` | Partial date object, not forced timestamp |
| Rating | `ratingsSummary.{aggregateRating,voteCount}` | Rating and integer vote count |
| Plot | `plot.plotText.plainText` | Plain text; HTML decoding is unnecessary for this selection |
| Runtime | `runtime.seconds` | Integer seconds, replacing formatted runtime parsing |
| Genres | `titleGenres.genres[].genre.text` | Genre labels |
| Certificate | `certificate.rating` | Regional content rating string (US headers used) |
| Related titles | `moreLikeThisTitles.edges[].node` | Reusable title summaries; select summary fields in final backend query |
| Seasons | `episodes.seasons[].number` | Season identifiers; count length only when complete list is returned |
| Episode count | `episodes.episodes.total` | 62 unfiltered Breaking Bad episodes; movie `episodes` is null |

The related-titles samples returned two results with `hasNextPage:false` and `endCursor:null`; do not assume this connection supports complete traversal. Presence in two examples does not imply non-null schema fields. Use tolerant parsing until broader evidence establishes required fields. Missing end year alone does not prove a series is ongoing.

## Credits and people

[Credit request](imdb-research/title-credits.request.json), [response](imdb-research/title-credits.response.json).

`title.cast` is not a public GraphQL field (recorded validation failure in [initial detail response](imdb-research/title-detail-initial.response.json)). Use `credits(first:2)` connection instead: `edges[].node` has `__typename`, `category.{id,text}`, and `name.{id,nameText.text,primaryImage.url}`. `... on Cast { characters { name } }` exposes characters for cast credits. `principalCredits[]` supplies `category` and `credits[]` containing polymorphic `Cast`/`Crew` objects and named people; Matrix categories were director, writer and cast. The first general credit page happened to contain actors; no claim is made that unfiltered credit pages always contain actors. Full cast filtering and ordering remain unverified. Principal credits are featured people, not a complete crew list.

Model `PersonSummary` separately from `Credit` so one person can have multiple categories and multiple characters. Avoid copying Electron's first-character-only loss of information. The credit page provided an opaque `endCursor` and `hasNextPage:true`; continuation was not exercised for credits.

## Trailer/video

`primaryVideos(first:1).edges[].node` yielded `id`, `name.value`, `description.value`, `thumbnail.url`, and `playbackURLs[].{url,mimeType}`. A primary video is not necessarily a trailer: inspect metadata, and do not hard-code its semantic role. Responses contained signed MP4 and HLS links with `Expires`, `Signature`, and `Key-Pair-Id`; store the video ID/metadata and refresh playback URLs rather than treating them as permanent. Media playback itself was not tested. This is richer than scraping a trailer embed link but does not establish codec compatibility.

## Seasons and episode pagination

[First page request](imdb-research/title-episodes-page1.request.json), [response](imdb-research/title-episodes-page1.response.json), [second page request](imdb-research/title-episodes-page2.request.json), [response](imdb-research/title-episodes-page2.response.json).

```graphql
query($id: ID!, $season: String!, $after: ID) {
  title(id: $id) {
    episodes {
      seasons { number }
      episodes(first: 2, after: $after, filter: {includeSeasons: [$season]}) {
        total
        edges {
          node {
            id titleText { text } primaryImage { url }
            plot { plotText { plainText } }
            ratingsSummary { aggregateRating voteCount }
            releaseDate { year month day }
            series { episodeNumber { seasonNumber episodeNumber } }
          }
        }
        pageInfo { endCursor hasNextPage }
      }
    }
  }
}
```

Variables `id:tt0903747`, `season:"2"` returned episodes 1/2, then passing the first endCursor as `after` returned episodes 3/4. `total:13` is the filtered season total, whereas the unfiltered detail request returned 62. Both pages had `hasNextPage:true`. Numeric `series.episodeNumber` replaces parsing Electron's displayable number strings. Use opaque cursor pass-through; do not derive/decode IDs to advance pages. Season identifiers are strings in the filter even though returned season numbers were numeric. Specials, unknown numbers, series relationships for standalone titles, and episode sort controls remain unverified.

## Reviews

[First page request](imdb-research/title-reviews-page1.request.json), [response](imdb-research/title-reviews-page1.response.json), [second page request](imdb-research/title-reviews-page2.request.json), [response](imdb-research/title-reviews-page2.response.json).

`title(id:$id).reviews(first:2,after:$after,filter:{spoiler:EXCLUDE},sort:{by:HELPFULNESS_SCORE,order:DESC})` returned `total`, `edges[].node`, and `pageInfo.{endCursor,hasNextPage}`. The next opaque cursor returned a different pair of review IDs. The unfiltered sample total was 5322, spoiler-excluded total 4723; counts are time-dependent observations.

Review node fields verified: `id`, `author.nickName`, `authorRating`, `summary.originalText` (string), `text.originalText.plainText`, `submissionDate` (date string), `helpfulness.{upVotes,downVotes}`, `spoiler` (boolean). Select plainText to remove HTML handling. Ratings/author/text nullability and other sort/filter enum values remain unverified. Preserve review IDs and spoiler metadata; don't expose full review loading as part of every title-detail request.

## Backend implications and boundaries

Use separate domain operations for title detail, episode pages and review pages while sharing a title-summary projection and one connection decoder. Edges remain part of the wire format, but decoding should happen once in the repository rather than throughout presentation. Related title cards, credits/person photos and a bounded episode preview can be resolved alongside the title in one native POST. Subsequent requests are still needed for actual pagination. No per-person enrichment requests are necessary for the selected person fields.

`meterRanking.currentRank` and `productionStatus.currentProductionStage.text` returned values, but response `extensions.entitlements.fields` marked both `DENY`. Do not interpret this as assured access or include them in the first stable contract. The title responses also flagged fields as experimental. All live responses included IMDb's usage disclaimer linking to [IMDb's own data-use requirements](https://help.imdb.com/article/imdb/general-information/can-i-use-imdb-data-in-my-software/G5JTRESSHJBBHTGX#); observed technical access does not establish permission for application distribution. Authentication-free success on this machine does not establish reliability/rate limits across installed users.


## Landscape image / backdrop candidates

A follow-up native full-query probe verified `title.images(first:5)` with
`edges[].node.{id,url,width,height,type}` for Breaking Bad (`tt0903747`) and
The Matrix (`tt0133093`). See [query](imdb-research/title-backdrop-candidates.graphql)
and [evidence](imdb-research/title-backdrop-evidence.json).

Breaking Bad's primary image was a 2000×3000 poster. Its first five gallery
images were `still_frame` images around 2048×1365: landscape photographs that
can be selected/cropped for a detail-page background. This exposes candidates,
not an explicitly designated or guaranteed Netflix-style backdrop asset.
The title response marked `Title.images` as entitlement `DENY` despite returning
images. Access remains qualified accordingly.

Proposed mapping: select a landscape still with adequate width from a bounded
image page; retain original dimensions and image type. Aspect ratio, crop,
spoilers, embedded text and image quality need product consideration. Gallery
ordering does not establish which image is the best hero. A wider gallery,
type-filter argument, dedicated background field and availability across titles
have not been verified. Do not silently promote a poster or arbitrary video
thumbnail into a guaranteed backdrop.
