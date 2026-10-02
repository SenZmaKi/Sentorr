# Anitomy compatibility for movies and TV

Evaluated on 2026-10-02 against the owned `../anitomy_dart` source and published
`anitomy_dart` 1.0.1. Published `lib/src/parser.dart` matched the inspected checkout
byte-for-byte. Sentorr consumes the published package; no sibling edits are needed.

The anime label does not imply different fundamental episode semantics. Anitomy
handles scene and long-form TV episodes, bracketed metadata and explicit ranges.
Sentorr now uses it for season and episode extraction through
[release_metadata.dart](../../lib/torrents/release_metadata.dart). Each call owns
a fresh parser and retains all episode numbers rather than only the first.

Source review and executable probes established these differences:

| Example | Raw Anitomy 1.0.1 | Sentorr adaptation |
| --- | --- | --- |
| `Breaking.Bad.S01E01` | Season 1, episode 1 | Use extracted values |
| `Breaking Bad 1x01` | Season 1, episode 1 | Use extracted values |
| `Breaking.Bad.S01E01-E03` | Episodes 1 and 3 | Reject ambiguous ranges |
| `Breaking.Bad.S01E01 E02` | Episode 1; E02 becomes episode title | Guard against extra episode markers |
| `Breaking.Bad.S01.Complete` | S01 remains in title | Normalize S01 to Season 1 |
| `Doctor.Who.S00E00` | No extracted season/episode | Normalize to Season 0 Episode 0 |
| `The.Office.2005.S02E03` | Parsed title includes 2005 | Contextual title/year validation |
| `1917.2019.1080p` | Both numbers remain in title | Preserve numeric title and validate actual year |
| `The.English.S01E01` | English becomes language; title is The | Validate original title; language hints only from metadata suffix |
| `4K` | videoTerm rather than videoResolution | Sentorr resolution normalization |

Relevant source methods in Anitomy `lib/src/parser.dart` are
`_matchSeasonAndEpisodePattern`, `_searchForLastNumber`,
`_searchForIsolatedNumbers` and `_searchForAnimeTitle`; language and season
keywords live in `lib/src/keyword.dart`. These heuristics explain why trusting
all raw parsed fields would lose movie/TV identity or admit false matches.

Sentorr retains focused identity policy: explicit TV season syntax, full-title
comparison, sequel-number checks, explicit year, provider IMDb identity,
language hints and range rejection. Bare absolute anime episodes such as
`Title - 01` cannot establish a TV season and are rejected. Ambiguous packs need
actual file inspection before playback. No modifications to Anitomy were made.

Tests cover scene/long/cross forms, numeric titles, zero-valued specials,
bracketed languages, subtitle hints, ranges, wrong episodes/seasons and reboot
years in `test/torrents/release_metadata_test.dart`, `show_matching_test.dart`
and `show_resolution_test.dart`.
