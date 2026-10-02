# IMDb migration probe

Historical investigation. For the implemented backend and current commands,
see [README](README.md).

The root Dart package is the first application-domain slice, usable from the
future Flutter application. Existing Flutter demos remain separate packages.
The injected Dio boundary follows Senpwai's networking structure without
pulling in its persistence, downloads, or browser transport.

## Run

```sh
dart pub get
dart run tool/imdb/check.dart suggest matrix
dart run tool/imdb/check.dart trending
# Override the legacy query hash when a current PopularTitles hash is available:
IMDB_POPULAR_TITLES_HASH='<64 hexadecimal characters>'
dart analyze lib test tool/imdb
dart test
```

`lib/imdb/repository.dart` contains two explicit operations, with cancellation
and bounded network timeouts. It never substitutes suggestions for popular
titles after failure.

## Initial direct-request probe on 2026-10-02

- The Dart suggestion request returned HTTP 200 and seven title records for
  `matrix`, including `tt0133093`, The Matrix (1999). Franchise entries are
  excluded, as are person entries. This endpoint has no query hash or API key.
- The migrated Electron `PopularTitles` request returned HTTP 403. Direct GET
  and a minimal GraphQL POST also returned HTTP 403.
- Requests to IMDb's homepage and advanced search page returned HTTP 202 with
  empty bodies. We could not obtain their script assets or extract a fresh hash.
- Six offline tests pass for request variables, parsing, nullable fields,
  GraphQL errors, unexpected responses, suggestion filtering, and validation.

A 403 does **not** establish that the stored query hash has expired: we never
received a GraphQL `PersistedQueryNotFound` response. The original persisted
query mechanism therefore remains unverified, rather than disproved.

## What the old key means and automation boundaries

Electron's five 64-character constants are SHA-256 persisted-query identifiers,
not authentication keys. Each refers to a query registered by IMDb's web app.
Changing one constant cannot fix a server rejecting the HTTP request itself.

If the web page and its assets become readable, discovery could inspect its
JavaScript for the exact operation's registered hash, followed by a live query
and response-shape check. Hash discovery is coupled to IMDb's changing asset
format and cannot be considered proven from this run. No automatic hash
refresh or browser transport has been added. The constructor/environment
injection allows a discovered hash to be tested without editing source.

## Scope and alternatives

Suggestions provide title IDs, names, years, types, and posters. They do not
provide the advanced filtering, ratings, pagination, episodes, reviews, or
full metadata used by Electron. Both endpoints are unofficial website services.
The current model deliberately covers only this initial summary slice.

IMDb's documented API is a separate GraphQL product through AWS Data Exchange
with subscription/access-key onboarding:
https://data.imdb.com/documentation/api-documentation/
That is a supported alternative to investigate if the website service remains
unavailable; it has not been integrated or assessed for cost here.

No browser inspection was used in the initial probe. The follow-up below used
a live browser at the user's explicit request. No UI or playback work was included.


## Follow-up: live browser discovery

The in-app browser successfully loaded the actual IMDb homepage. Its rendered
HTML was approximately 2.56 MB. Inspecting inline script contents found no
64-character hexadecimal hashes. The homepage JavaScript bundle contains
GraphQL query documents (including `FanFavoritesHomepage` and
`TopMeterTitlesWidget`); the exact persisted identifiers were recovered from
IMDb's own network requests, rather than guessed from nearby JavaScript text.

Discovery procedure:

1. Open `https://www.imdb.com/` in a live browser.
2. Enable Network capture before reloading.
3. Scroll through the homepage to load lazy title widgets.
4. Filter requests for `graphql.imdb.com` and record `operationName`,
   `variables`, and `extensions.persistedQuery.sha256Hash` together.
5. Inspect the corresponding response for GraphQL errors and expected data;
   HTTP 200 alone does not establish success.
6. Replay the request through Dart without browser credentials to distinguish
   a usable application endpoint from browser-session-only behavior.

The observed requests are recorded in `tool/imdb/homepage_queries.json`,
without cookies, session identifiers, or account information.

### Verified results

- Current hosts observed: `api.graphql.imdb.com` and
  `caching.graphql.imdb.com`.
- `BatchPage_HomeMain` uses the hash
  `f6ccf12469ab9e9f3faed4718a6c0c447065d8db21afe7ce18f05488424c3bd1`.
- In the browser, this operation returned 30 recommendations, 10 trending
  titles, 30 fan favorites, and 50 interests, with no GraphQL errors.
- The native Dart probe returned all 10 trending titles, including ratings,
  with no cookies or `x-amzn-sessionid`. The recommendations and fan favorites
  sections returned explicit errors requiring that session header. This is
  partial homepage success, not a fully migrated homepage.
- Replaying the legacy `PopularTitles` query on the current API host with the
  observed public headers returned `PersistedQueryNotFound`. Unlike the initial
  403, this confirms the old hash is not accepted by the current API host.

Run the repeatable native homepage check:

```sh
dart run tool/imdb/check_homepage.dart
```

It prints section errors explicitly and validates the trending section.
`IMDB_HOMEPAGE_HASH` can override the captured hash for future rechecks.
The original repository probe now uses the current API host and public headers;
its default legacy `PopularTitles` hash remains intentionally marked as legacy.

Hash capture from a live browser is proven. Unattended hash refresh, session
bootstrap for personalized sections, other Electron operations, and reliability
across different users/networks remain unverified. The current homepage batches
several query sections, so migration can require changed operation names,
variables, and response parsing in addition to updating hashes.


## Preferred application route: owned full queries

The follow-up investigation verified that IMDb accepts full GraphQL documents
without a website persisted hash. Sentorr now owns `SentorrTrending` in
`lib/imdb/queries.dart`; `ImdbRepository.trendingTitles()` sends it as a JSON
POST with an object-valued `variables` field. The live Dart invocation returned
10 titles with no GraphQL errors and no browser, cookies, session ID, or hash.

```sh
dart run tool/imdb/check.dart trending
```

This is now the default check operation. `popular` retains the legacy hash
probe explicitly, while `check_homepage.dart` retains the captured website
batch probe. Eight offline tests and scoped analysis pass.

No hash-refresh interceptor is necessary for this owned-document slice. A
website bundle update or server eviction of a persisted hash does not require
Sentorr to discover a replacement identifier. Schema changes and native access
blocks remain possible. See `imdb-hash-refresh-research.md` for evidence on
IMDb's APQ negotiation and the separate WebView/session fallback question.


## Entity research and backend design

See [the backend map](imdb-backend-map.md) for the proposed application
contracts and migration sequence, backed by [catalog shapes](imdb-catalog-shapes.md)
and [title, episode, credit and review shapes](imdb-title-entities.md).
This research adds query/evidence documents only; those features have not yet
been implemented in the Dart repository.
