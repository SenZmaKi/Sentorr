# Downloads, streaming and following

Status: agreed with the owner on 2 October 2026 and implemented in all five
phases below; update this file when a decision changes.

## One torrent engine

Streaming and downloading are one domain. A single long-lived isolate owns a
single libtorrent session, the loopback media server and every torrent handle.
The binding has process-wide registries, so no other isolate makes native calls.

- A torrent is added once per info hash. Callers hold it as **owners** (a
  download, a stream, ...). It leaves the session when its last owner releases it.
- Each owner states which files it **wants** downloaded in full. The torrent
  downloads the union at normal priority; nothing else is fetched.
- A **stream** attaches to a torrent's file and serves it over loopback HTTP.
  Its piece scheduler raises priority and sets deadlines just ahead of each
  read, then returns pieces to their base priority. Playing a file that is
  downloading only adds deadlines; closing the stream returns to plain downloading.
- **Storage** has a rank: temporary < retained (stream cache) < kept (download).
  An owner with higher-ranked storage moves the torrent there (`moveStorage`),
  so downloading what is being watched reuses every piece already fetched.
- Pausing is per owner; a torrent pauses only when every owner pauses it, so
  an attached stream always runs.

`packages/torrent_stream` owns the engine and stays free of Sentorr concepts.
Policy (download queue, seeding, cache retention, pausing downloads while
watching) lives in the app on the main isolate, driven by engine snapshots.

## Downloads versus the stream cache

| | Stream cache | Downloads |
| --- | --- | --- |
| Owner | App, evicted oldest first | User, never removed automatically |
| Location | `cache/streams/<infohash>` or the chosen torrent folder | Downloads folder, readable names |
| Layout | Torrent's own paths | `Series/Season 01/Series S01E03.ext`, `Movie (Year)/Movie (Year).ext` |
| Cleared by | Storage → clear | Deleting the download |

`lib/library/` maps IMDb ids (movie or episode) to downloads: download id,
file index, release and path. Buttons, the player and auto-download read it
instead of scanning the disk. Completed downloads play as local files; one in
progress streams from its own torrent.

## Settings

- **Network** (shared by streams and downloads, one session): download and upload
  limits, connections, uTP, DHT, LSD, UPnP, NAT-PMP.
- **Streaming**: read-ahead, piece memory, timeouts, recent torrents kept (cache).
- **Downloads**: folder, simultaneous downloads, pause downloads while watching
  (on), seeding (off / until ratio and time / always) and simultaneous seeds.
- **Following**: auto-download default (off / series I turn on / every series I
  follow), episodes kept per auto-downloading series (0 keeps all, the default).

## Following and auto-download

Following stays the single tracking concept: watching an episode follows its
series, and a Follow button follows or unfollows manually. Each followed series
has notify and auto-download switches; auto-download defaults from settings.

When auto-download is on, every aired episode after the furthest one watched
downloads, oldest first, whether or not the viewer is caught up (up to 20 per
check). A series followed without watching counts its latest aired episode as
reached, so only episodes airing after it was followed download. Only exact
torrent matches download automatically; others wait under "Needs your choice"
on the Downloads page until downloaded or dismissed (dismissals last until
restart). A notification says when an episode is ready, replacing that
series' new-episode notice.

Checks run with the new-episode check (a minute after start, then every three
hours) and at once when a series' switch or the settings default turns on.
Code: `lib/following/auto_downloads.dart`, `lib/following/due_episodes.dart`.

## Phases

1. Engine: shared session, owners, wants, storage moves, streams on any torrent.
   The player and download queue move onto it; the download isolate goes away.
2. Library and playback: IMDb-keyed downloads, readable layout, local playback.
3. UI: download button (progress ring) on episode rows, previews and the
   title page; Downloads page.
4. Settings: Network, Downloads and Following groups.
5. Following: Follow button, per-series switches, auto-download and retention.
