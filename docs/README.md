# Sentorr developer documentation

Start with the root [README](../README.md) for builds and [AGENTS.md](../AGENTS.md)
for implementation conventions. [DESIGN.md](../DESIGN.md) owns UI rules.

## Architecture and behavior

- [Application infrastructure](app-infrastructure.md): service ownership,
  persistence, lifecycle and verification entry points.
- [Networking](network-stack.md) and [IMDb backend](IMDB/README.md).
- [Torrent resolution](Torrent/TORRENT_RESOLUTION.md),
  [source adapters](Torrent/torrent-sources/README.md) and
  [filename parsing](Torrent/parser-evaluation.md).
- [Torrent playback engine](Torrent/torrent-playback-engine.md) and
  [downloaded timeline](downloaded-timeline.md).
- [Downloads architecture](downloads/ARCHITECTURE.md) and
  [queue implementation](downloads/README.md).
- [Device sync and backup](sync/ARCHITECTURE.md).

## Operations and validation

- [Release signing](signing-keys.md), [nightly releases](nightly-releases.md)
  and [Android Drive OAuth](android-drive-oauth.md).
- [macOS native playback](playback/MACOS_NATIVE_PLAYBACK.md).
- [Performance decisions and measurement](performance/README.md).
- [Critical-module audit checklist](sanity-checks.md) and
  [22 October repair report](audits/fixes-2026-10-22.md).

Architecture documents describe intended ownership and behavior. Dated audits,
provider snapshots and lab reports describe their recorded revision and retain
explicit validation limits; consult the repair report for the latest audit fixes.
Superseded proposals, migration notes, the standalone design demo and old raw
profiling dumps are available in Git history rather than maintained here.
