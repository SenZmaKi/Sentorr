# Sentorr networking

`lib/shared/net/` adapts the relevant Senpwai patterns: injectable Dio, body-aware
POST caching, scoped cancellation, host concurrency, bounded rate-limit retries,
and HTTP/2 preference. It does not import Senpwai's app identity, settings,
provider routes, cookie directory, browser runtime or download subsystem.

## Ownership

```dart
final network = NetworkClient(cacheDirectory: sentorrCacheDirectory);
final imdb = ImdbRepository(network.dio);
try {
  final page = await imdb.searchTitles(ImdbSearchFilters(term: 'matrix'));
  // Domain data, not GraphQL edges.
} finally {
  await network.close();
}
```

The embedding application supplies its own writable Sentorr cache directory.
Without it, the store is in-memory. `NetworkClient` closes the transport and any
store it creates; injected stores remain caller-owned. `clearCache()` clears
cached entries. No application singleton or Flutter UI bootstrap is required.

## Behavior

- 15-second connect timeout, 20-second send/receive timeouts, 3-minute idle
  connection timeout. These do not impose a total end-to-end request deadline.
- Four in-flight requests per host by default. Queued cancellation removes work
  without consuming a permit. Pass `perHost` to configure the application limit;
  it is not a claim about IMDb's provider quota.
- Explicit `CancelToken`s and Senpwai-style scoped cancellation propagate through
  queued work and rate-limit waits.
- Caching is off for generic requests. IMDb explicitly marks its GraphQL POSTs
  as read-only and opts them into caching. Cache keys hash the URL, body and
  representation/session headers, so different variables/locales cannot share
  an entry. Search/autocomplete use 2 minutes; catalog/detail pages use 1 hour.
- `refresh: true` forces a network fetch. Read-only GraphQL failures and partial
  responses with `errors` are not cached, even when HTTP status is 200. No stale
  error/network fallback is enabled. Cache hits are subject to the operation's
  maximum age.
- One HTTP 429 retry for GET/HEAD or explicitly marked replayable read POSTs.
  Honor Retry-After seconds/date values up to 30 seconds; longer values surface
  the original error. CancelToken cancels the wait. Mutation/stream requests,
  403/202 responses and schema errors are not automatically replayed.
- `Logger('sentorr.net')` emits FINE records for method, host/path, status/error
  type and elapsed time. The embedding app configures logging listeners/level.
  Query strings, bodies, headers, credentials and response contents are omitted.
- `dio_http2_adapter` prefers HTTP/2, with the existing native adapter as fallback.
  The wrapper closes both transports. Transport-error replay is restricted to
  body-free GET/HEAD; it does not replay a partially transmitted POST. Disable
  HTTP/2 with `http2: false`. No benchmark or performance improvement is claimed.

## Dependencies checked on 2026-10-02

Published package metadata and `dart pub outdated` confirmed the latest
compatible resolved versions: Dio 5.11.1, dio_cache_interceptor 4.0.7,
http_cache_file_store 2.0.2, logging 1.3.0, crypto 3.0.7 and
dio_http2_adapter 2.9.0. The adapter declares `http2: ^2.1.0`, so 2.3.1 is the
latest compatible version; 3.1.0 is available but cannot be forced without
changing the adapter. There is no HTTP/3 dependency.

Primary sources: [Dio/HTTP2 adapter](https://pub.dev/packages/dio_http2_adapter),
[Dio cache interceptor](https://pub.dev/packages/dio_cache_interceptor),
[file cache store](https://pub.dev/packages/http_cache_file_store).

## Verification

```sh
dart analyze lib test tool/imdb
dart test
```

Local HTTP-server tests verify cache body isolation, refresh/clear, persistent
cache reopening, GraphQL failure rejection, safe logs, cancelled queues, bounded
429 retry, cancellation during cooldown and HTTP/1 compatibility with HTTP/2
preference enabled. Live catalog requests validate the production stack on this
Mac; they do not establish behavior on every target platform or user network.
