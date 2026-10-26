# Local validation — 25–26 October 2026

## Automated checks

- App sync/player and relevant home/audio/player UI suites: **295 passed,
  2 existing skips**.
- Owned `torrent_stream` package, run from its directory with
  `dart test --concurrency=1`: **106 passed**.
- `flutter analyze --no-pub`: no issues.
- Scoped Dart formatting, Python launcher syntax and diff whitespace checks.

Coverage includes failed/duplicate/stale handoffs, pairing revocation, cached
partial bytes with the seed offline, exact torrent/file fallback, saved playback
and seek positions, local pause/caption changes after handoff, source replacement
cancellation, silent-stall detection, finite retry budgets, resumed byte ranges,
range substitution rejection, upstream cancellation and observed TLS connection
reuse. The offline-home harness uses an unpaired device; unpaired continuity
creates neither a polling timer nor a sync service.

## Native two-process checks

All app windows remained hidden. Each app had separate state, identities and
native playback, using real mutually authenticated HTTPS and a loopback proxy.

- Completed-file handoff decoded video and advanced from the source's final
  position while the source remained paused.
- Unfinished-torrent handoff used roughly 37 MB of a 314 MB fixture cached on
  the host. The receiving app owned **zero torrents** during peer playback.
- Multitrack MKV: audio track 2, subtitle track 2, captions enabled, speed 1.25
  and volume 37 were restored on the receiver.
- External-caption check: the source retained automatic audio; continuity resolved
  native track 1, imported the subtitle as transient text, and retained caption
  visibility. Receiver settings contained the descriptor `external`, with no host
  path or caption text.

The outage harness uses a receiver-hosted independent TCP torrent seed and tiny
local tracker. It suspends or kills the source process and seeks beyond the normal
forward buffer, so cached player packets cannot make the check pass alone.

- Three-second host suspension: peer playback resumed at the seek position in
  about four seconds, with **zero receiver torrents**.
- Permanent host disappearance: the receiver opened the original torrent/file
  locally and advanced past the requested 180-second position after about
  31 seconds, with **one receiver torrent**, rate 1.25 and volume 37.

The initial handoff timing fields include subsequent verification waits; they
are not measurements of perceived visual interruption. Outage recovery timing
includes retry budgets, torrent startup and advancement after the seek.

## Boundaries

No physical-phone, Wi-Fi, Android lifecycle, audible-quality or visual-smoothness
assessment was performed. Hidden checks mount production PlaybackEngine/Video
from the first frame; interactive mode uses the full app and PlayerHost. Local
fallback still requires usable metadata and a reachable torrent swarm.

An initial parallel package run hit a small MKV fixture's partial-byte assertion;
its isolated and full sequential reruns passed. Package tests must run from their
own directory because their fixtures use package-relative paths.
