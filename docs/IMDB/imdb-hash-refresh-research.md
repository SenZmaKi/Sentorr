# IMDb queries without browser bootstrap

Investigated on 2026-10-02. No browser inspection tools were used for this
follow-up. These are observations about the unofficial website API, not an
IMDb service guarantee.

## Verified native route

A native HTTP POST to `https://api.graphql.imdb.com/` containing this complete
query returned HTTP 200, The Matrix's ID and title, and no GraphQL errors:

```graphql
query SentorrHashProbe {
  title(id: "tt0133093") {
    id
    titleText { text }
  }
}
```

The request used ordinary public website headers and no cookie, session ID,
account credential or browser. Sending the same full query with a SHA-256
`extensions.persistedQuery` also succeeded. A subsequent hash-only POST using
that locally computed hash succeeded. This sequence demonstrates registration
and replay for this document; it does not establish the cache lifetime or that
all IMDb operations allow this behavior.

The concurrent Sentorr probe also verified an owned `SentorrTrending` full
query with `topMeterTitles(first: 10)` through native GET, returning ten titles
without GraphQL errors. Dart verification is recorded in the main integration
notes. GET query encoding must preserve JSON accurately; the successful probe
used percent-encoded spaces rather than `+`.

## IMDb's actual client behavior

The current public
[IMDb app JavaScript](https://dqpnq362acqdi.cloudfront.net/_next/static/chunks/pages/_app-bf10365fc6c55bd1.js)
was fetched successfully through native HTTP. Its persisted-query exchange:

- Computes SHA-256 from the serialized query document.
- Initially omits `query` and sends `extensions.persistedQuery`.
- Restores the complete query after `PersistedQueryNotFound`.
- Falls back without persisted extensions after `PersistedQueryNotSupported`.

The client initialization enables `preferGetForPersistedQueries` and does not
enable `enforcePersistedQueries`. Its GET builder switches to POST when the URL
exceeds 2047 characters. These are observations of this specific asset; its
filename and implementation can change.

This is the same negotiation pattern documented by
[Apollo's persisted-query implementation](https://github.com/apollographql/apollo-link-persisted-queries):
the hash identifies a query document, and the full document lets a server
register it after a cache miss. A missing persisted document can therefore be
cache eviction, not necessarily a website schema change.

## Recommended Sentorr boundary

Start with small, owned complete GraphQL documents for public catalog fields.
Send the full document directly. This avoids scraping IMDb's current frontend
bundle and removes a browser-bootstrap dependency for verified operations.
It also avoids the homepage batch's session-dependent personalized sections.

If request size later justifies APQ, compute the hash locally from the exact
query string and retain that same string for fallback. Allow one full-document
retry on an explicit persisted-query miss; coalesce simultaneous registration
attempts and retain cancellation/timeouts. Ordinary GraphQL errors may appear
inside HTTP 200 responses, so the domain client must inspect them rather than
relying solely on Dio's transport-error interceptor.

An HTTP 403, empty HTTP 202, network failure, authentication error, schema error
or malformed payload is not a persisted-query miss. Do not interpret these as
instructions to discover a new hash. Schema changes still require adapting
Sentorr's documents and parsers; refreshing a hash cannot repair them.

## Browser fallback and limits

Senpwai's `lib/shared/net/browser_transport/` supplies browser-backed Dio
transport with origin bootstrap, browser-owned cookies/headers, cancellation,
serialized navigation and visible challenge recovery. It can inform a future
Sentorr fallback if native public requests become blocked. It currently does
not implement IMDb hash discovery, and copying it does not prove IMDb support.
A hidden WebView may still need visible interaction and platform-specific
support. Those properties remain unverified for IMDb and Sentorr.

The main integration probe found that homepage recommendations and fan
favorites need `x-amzn-sessionid`; the trending section did not. Do not invent a
session value or treat this observation as a requirement for all catalog APIs.
Native requests succeeding on this machine does not establish behavior across
users, networks, platforms or future IMDb releases.

Successful API responses also carry a data-use disclaimer linking to
[IMDb's software data-use guidance](https://help.imdb.com/article/imdb/general-information/can-i-use-imdb-data-in-my-software/G5JTRESSHJBBHTGX#).
Technical access does not establish redistribution permission.
