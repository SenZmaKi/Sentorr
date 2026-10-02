# Torrent sources

Flutter source-only migration, validated on 2026-10-02. No download manager,
libtorrent session, player, torrent-file fetch, or UI is involved.

## Providers

| Provider | Flutter | Live finding |
| --- | --- | --- |
| Pirate Bay | `PirateBaySource`, `https://apibay.org/q.php` | API responds with JSON and usable seeded releases. |
| YTS (`yts.mx`) | `YtsSource`, `https://movies-api.accel.li/api/v2/list_movies.json` | Old host failed DNS here. `https://yts.gg/api/v2/list_movies.json` advertises the new base in `@meta.migration`; the new endpoint returns valid movie metadata. |
| Bitsearch | `BitsearchSource`, `https://bitsearch.eu/search` | Replaces SolidTorrents: the old `solidtorrents.to/search` redirects here; the HTML structure has changed. |
| RARGB (`rargb.to`) | Excluded | Old endpoint returned HTTP 403. Excluded at the user's request; no Flutter adapter or default requests. |

These findings are observations from this machine, not an uptime guarantee.
The old Electron sources remain as historical migration references.

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
- Results use magnet URIs consistently, including YTS. Search does not retrieve
  torrent files. Bitsearch's supplied magnet trackers are preserved.
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
