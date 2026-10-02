# Torrent resolution

`TorrentResolver` maps movie, season or episode intent to ranked torrent releases.
It is available through `torrentResolverProvider` and uses the existing shared
Dio transport and Pirate Bay, YTS and Bitsearch adapters. YTS supports movies
with IMDb IDs; the other adapters support title searches.

```dart
final result = await ref.read(torrentResolverProvider).resolve(
  TorrentQuery(title: 'Example Show', season: 2, episode: 0),
  preferences: TorrentPreferences(
    preferredResolution: 1080,
    maximumSizeBytes: 8 * 1024 * 1024 * 1024,
    allowSeasonPackFallback: true,
  ),
  cancelToken: cancelToken,
);
final candidate = result.best;
```

Source adapters validate identity before ranking: title, explicit year,
season/episode, language when requested, and provider-supplied IMDb identity.
Unknown language does not satisfy a language restriction. Release names with
ambiguous episode/season ranges and movie collections are rejected. Season and episode extraction uses published `anitomy_dart` 1.0.1 through a
small Sentorr adapter. See the [parser evaluation](parser-evaluation.md).
General video titles can be searched without IMDb IDs; arbitrary software,
books and other non-video torrents are outside these source adapters' scope.

The repository searches supported sources concurrently and deduplicates hashes,
retaining the strongest reported swarm. Ranking enforces minimum seeders,
optional maximum bytes and optional known resolution. It also rejects malformed
hashes, magnets that disagree with the hash, and invalid sizes or resolutions.
Seed counts are provider reports, not verified availability.

Scores use fixed scales: 55% closeness to preferred resolution, 40% seeder
availability (`seeders / (seeders + 100)`), and 5% preference for smaller releases.
Availability increases with diminishing returns and has no hard seeder cap. Unknown
resolution gets zero quality credit. Fixed scales prevent an outlier from
changing other candidates' scores. Ties prefer seeders then hash. All eligible
candidates remain available to the caller for manual selection or retry.

Show searches try `SxxExx`, then `Season x Episode y`, then `1x01` only while
no eligible candidate exists. `allowAlternateSearchFallback` defaults to true;
disable it to run only the primary query. Pack searches have two distinct forms:
`Sxx` and `Season x`. `allowSeasonPackFallback` remains disabled by default.
When enabled, it follows an unsuccessful episode search, preserving title,
series IMDb ID, year, season, language restrictions and ranking limits, and
removing the episode IMDb ID. The maximum is three episode plus two pack attempts.
All-provider failure stops fallback. No fallback silently relaxes restrictions.
A pack sets `requiresFileSelection`; inspect its files before selecting an episode.

`allowResolutionFallback` defaults to true: quality different from the preferred
resolution remains eligible. Disable it to require an exact resolution, also
rejecting unknown resolution. Seed and size limits are always hard filters.

`resolved` means candidates exist, `noMatch` means searches completed without an
eligible result, and `unavailable` means there were failures and no candidates.
Failures are retained even alongside successful matches. Cancellation propagates
as a Dio cancellation exception and prevents fallback. Unexpected programming
errors propagate rather than being disguised as an empty search.

This engine selects magnets. It does not download, verify codecs, select files
inside torrents, or start playback. Integrating production playback remains a
separate feature.

Verification:

```sh
flutter test test/torrents
flutter analyze
dart run tool/torrent_sources/resolve.dart
# title, optional IMDb ID or -, season, episode or -, year
dart run tool/torrent_sources/resolve.dart 'Example Show' - 2 3 2020
```

The live command performs metadata searches only and reports partial provider
failures separately from candidates. Availability and layouts can change.

On 2026-10-02 the live default probe resolved Big Buck Bunny to 13 candidates
with no source failures. This verifies metadata discovery and ranking, not swarm
connectivity or playback.

## App integration

Play requests go through `playbackLaunchProvider` (`lib/player/launch.dart`)
before the player opens. It finds the item to play (building the season queue
for a series' first episode), maps it with `torrentQueryFor`, and resolves with
`TorrentSettings` from app settings (preferred resolution, languages; season-pack
fallback on). `TorrentMatch` (`lib/torrents/match.dart`) calls the best candidate
exact only at the preferred resolution in a single file. Other or unknown quality
and season packs are close matches, which always wait for the viewer. The chosen
candidate is stored in `PlayerSession.torrents` by item ID. Playback still uses
sample media until the streaming engine is connected, and later queue items are
not resolved yet.

## Reporting and recovery

`message` and `recoverySuggestions` are ready for app presentation. `attempts`
records each query/stage, identity-valid and eligible counts, source status
(succeeded/failed/unsupported), failure text, source rejection counts and
`preferenceRejections`. Source failures retain the query's `searchText`.
`rejectionCounts` aggregates observations across attempts, not unique torrents.
Each rejected row records its first decisive reason. Partial success remains
visible in the user-facing message. Unsupported sources issue no requests.

Reasons distinguish wrong identity/title/year/season/episode, ambiguous ranges,
unconfirmed language, unavailable seeders, malformed metadata, and seed/size/quality
preference limits. Suggestions never change preferences automatically. Filename
language hints do not verify actual audio. Unknown language, unqualified MULTI
and subtitles-only hints cannot satisfy an audio language filter. Missing years
remain permissible; explicit conflicting years fail.

Transport owns bounded HTTP 429 retry. Other provider failures are retained; no
unlimited retry loops or automatic failed-swarm retries exist in this metadata
engine. Playback and actual file inspection remain separate work.

## Show validation

`dart run tool/torrent_sources/show_probe.dart` runs six live cases and saves
[the metadata report](show-live-validation.json). On 2026-10-02 it resolved
Breaking Bad S01E01 (18 candidates), The Office S02E03 (3), Chernobyl S01E01
(18), Doctor Who S00E01 (1), and English-filtered Breaking Bad S01E01 (1).
Planet Earth S01 had no match after two forms, with identity/title/year/episode
ambiguity and zero-seeder rejections recorded. No provider failures occurred.
These checks establish metadata discovery and ranking, not peer connectivity or
playback. Counts and source availability can change.
