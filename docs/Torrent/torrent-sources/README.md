# Torrent sources

Flutter search adapters and HTTP torrent metadata delivery. Search parsing was
validated on 2026-10-02; metadata download routes were checked on 2026-10-05.

## Providers

| Provider | Flutter | Live finding |
| --- | --- | --- |
| Pirate Bay | `PirateBaySource`, `https://apibay.org/q.php` | API responds with JSON and usable seeded releases. |
| YTS (`yts.mx`) | `YtsSource`, `https://movies-api.accel.li/api/v2/list_movies.json` | Old host failed DNS here. `https://yts.gg/api/v2/list_movies.json` advertises the new base in `@meta.migration`; the new endpoint returns valid movie metadata. |
| Bitsearch | `BitsearchSource`, `https://bitsearch.eu/search` | Replaces SolidTorrents: the old `solidtorrents.to/search` redirects here; the HTML structure has changed. |
| RARGB (`rargb.to`) | Excluded | Old endpoint returned HTTP 403. Excluded at the user's request; no Flutter adapter or default requests. |

These findings are observations from this machine, not an uptime guarantee.
The retired Electron sources are available in Git history at commit `b18f176`.

## Consumption

Use `torrentRepositoryProvider` from `lib/torrents/providers.dart` in Flutter;
it uses the bootstrap-owned `NetworkClient`. Non-UI callers can construct
`TorrentRepository.defaults(dio)` or inject a list of `TorrentSource`s.
Each adapter accepts an explicit endpoint override for tests/operator-managed
endpoint changes; there is no speculative mirror discovery.

```dart
final result = await repository.search(
  TorrentQuery(
    title: 'Example Show',
    imdbId: 'tt1234567',
    season: 1,
    episode: 0, // Special episodes are valid.
    year: 2020, // Optional; rejects explicit conflicting years/reboots.
  ),
  cancelToken: token,
);
// result.releases and result.failures are separate immutable lists.
```

A season with no episode searches for a season pack; no season searches movies.
An optional `episodeImdbId` allows Pirate Bay to recognize either a series or
individual episode ID, while still validating the requested season and episode.
YTS supports movies with an IMDb ID only and is skipped for series/title-only
queries. Unsupported sources are skipped without issuing a request.

## Improvements and limits

- Source failures are retained separately from successful empty searches.
  Concurrent sources return partial results if another provider is blocked,
  unavailable, rate limited, or returns an unexpected page/schema.
- Cancellation propagates as cancellation, including after source aggregation;
  it is never converted into a successful empty result.
- The shared network stack owns per-host concurrency, request timeouts, and
  bounded/cancellable HTTP 429 retry. The old recursive unlimited RARGB retry
  was not carried over. Sources do not introduce a second retry loop.
- Hashes must be nonzero 40-character hexadecimal BitTorrent v1 hashes.
  Release sizes and seeder counts must be positive. Zero-seeder releases are
  excluded. Valid rows survive malformed neighboring rows.
- Results retain both magnets and HTTP metadata URLs. YTS supplies `torrents[].url`;
  Bitsearch supplies `/download/torrent/<hash>` links. Relative links use the
  configured source endpoint.
  APIBay supplies no torrent-file URL: its results use the HTTP iTorrents cache.
  Deduplication keeps metadata URLs from all sources, even when a different
  source has the largest observed seeder count.
- Playback and download planning fetch only the chosen release's `.torrent`
  through the shared HTTP transport, then supply metadata bytes to the engine.
  Provider URLs are tried before the hash cache. Older saved releases without
  URLs also use that cache. Requests are cancellable, limited to 15 seconds per
  location and 8 MiB of received metadata. Native parsing checks the expected
  info hash before torrent storage is created. Magnets remain available in
  results and persisted records, but these new paths never open them; failure
  to retrieve metadata uses the existing release-fallback flow. APIBay/cache
  coverage is therefore a dependency, and missing cache entries can fail.
- Discovery initializes alongside HTTP and renderer preparation. Streams expose
  HTTP while the header warms, fetch tails on player demand, prioritize a bounded
  upcoming piece window with deadlines, and target two seconds of initial playable
  buffer while continuing to read ahead. Faster startup can increase early stalls;
  public-swarm time to first frame has not been benchmarked by these checks.
- Tracker hints from magnets survive source deduplication and are supplied with
  HTTP metadata, including persisted download jobs. The magnet itself is not
  used for metadata acquisition. The shared HTTP/2 adapter decodes gzip before
  parsing source HTML or metadata, while avoiding double decoding after its
  HTTP/1 fallback. [Live metadata checks](metadata-validation.json) record
  matching native-parsed hashes for all four routes on 2026-10-05.
- Deduplicate by normalized info hash across providers, retain the largest
  observed seeder count, then sort by seeders and hash for deterministic ties.
  Different releases at the same resolution remain available.
- The Electron similarity function normalized `a` twice, effectively comparing
  the requested title with itself. The new full-title comparison uses both
  values, preserves Unicode letters/digits, and avoids token-subset matching.
  Numeric/short titles and sequel numbers require exact identity. Known IMDb
  identity can permit an alternate title, but never bypasses season/episode,
  explicit year, or movie collection checks.
- Movie collections and ambiguous multi-season/multi-episode ranges are rejected.
  Scene `SxxExxx` and `Season x Episode y` forms are supported. This is a focused
  movie/TV validator around Anitomy season/episode extraction. See the
  [parser evaluation](../parser-evaluation.md) for compatibility adaptations.
- Year and language information can be absent. An explicit year rejects
  conflicting metadata when present; it cannot prove identity when absent.
  Language filters require an explicit filename hint or YTS language metadata.
  Common English/French/Spanish/German/Japanese/Hindi/Italian names and ISO codes
  are normalized; unknown language does not silently become English. Filename
  hints do not prove the actual audio language.
- Unknown resolution and upload date remain nullable rather than inventing
  values or dropping otherwise valid releases. Bitsearch's locale-ambiguous
  dates are deliberately left unknown; JSON Unix dates are UTC.
- Bitsearch's current search container is required. Challenge pages and layout
  changes fail visibly rather than masquerading as no results. Its HTML adapter
  uses the `html` package and never executes remote scripts.
- Source adapters do not rank releases. The [resolution engine](../TORRENT_RESOLUTION.md)
  adds preference ranking, bounded fallback and diagnostics. File selection and
  streaming validation remain separate work.

## Validation

Deterministic tests use injected Dio responses and a stripped real Bitsearch
result-card fixture captured from a Big Buck Bunny search. It retains both
magnet links and HTML entities but excludes scripts and ads. Tests cover title
regressions, numeric titles, sequels/collections, episode zero, wrong seasons,
pack separation, reboot years, language filters, bad hashes/counts/dates,
query encoding, schema/access failures, source skipping, category icon changes,
partial success, cross-source deduplication, and cancellation.

```sh
flutter test test/torrents
flutter test
flutter analyze
```

Live probes are opt-in and never part of deterministic tests:

```sh
dart run tool/torrent_sources/probe.dart
dart run tool/torrent_sources/probe.dart 'The Matrix' tt0133093
dart run tool/torrent_sources/probe.dart 'Breaking Bad' tt0903747 1 1 2008
dart run tool/torrent_sources/probe.dart 'The Office' tt0386676 1 - 2005
```

Arguments: title, IMDb ID (`-` for absent), season, episode (`-` for a pack),
optional year. The default uses Big Buck Bunny. A provider failure sets a
nonzero process exit status; a valid zero-match search is still success.
Recorded snapshots are in `live-validation.json`. Seeders/results change over
time. Live checks validate metadata search and parsing, not peer availability,
file contents, codec compatibility, or playback. No browser inspection was used.

### Specialized sources

`SpecializedTorrentSource` separates an adapter's `appliesTo(TorrentQuery)`
condition from its search/parser implementation. Query genres come from the movie
or parent series catalog record and survive alternate searches and pack fallbacks.
Unknown genres do not activate genre-specific sources. General sources continue
searching alongside applicable specialized sources; source settings can disable
either kind.

Nyaa activates for the `Animation` genre and searches the English-translated anime
category (`1_2`), sorted by seeders, on the first page. Its shared
`SourceRequestGate(5)` caps concurrent requests across adapter instances and
endpoint mirrors, including retry waits; queued cancellation removes pending work.
The app transport may impose a lower per-host limit. New specialized adapters can
reuse the condition contract and give their source a shared request gate.

Nyaa uses the same conservative title/year/season/episode checks as other indexes.
Absolute anime episode numbering is not inferred to equal IMDb's season numbering;
those releases require a future explicit mapping. Empty result tables are successful
searches; access challenges or unrecognized layouts are source failures. Older
signed endpoint directories retain the built-in Nyaa endpoint until an entry is
provided by a newer directory.
