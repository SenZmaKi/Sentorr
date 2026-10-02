# Torrent download engine

`lib/downloads/` adapts Senpwai's torrent runtime, without its HTTP transfers,
app updater, anime planners, widgets, or toast dependencies. Native libtorrent
work runs in a dedicated isolate, independently of player streaming sessions.
App bootstrap restores the queue; lifecycle flush and shutdown await its writes.

## Entry points

Read `downloadRuntimeProvider` for commands, and `downloadsProvider` for snapshots.
The runtime can also be constructed directly with a state file and initial limits.

```dart
final runtime = ref.read(downloadRuntimeProvider);
final id = await runtime.enqueue(TorrentDownloadJob(
  title: 'Movie',
  torrentData: metadataBytes,
  destinationDirectory: destination,
  selectedFileIndices: [0],
));
await runtime.pause(id);
await runtime.resume(id);
```

Like Senpwai's `PreparedTorrentDownloadJob`, enqueue accepts resolved `.torrent`
metadata. Source discovery, magnet metadata resolution, destination picking, and
review UI belong to callers. Empty selection downloads all non-padding files.
Renames must stay inside the destination. Invalid selections are rejected before
starting the transfer. Duplicate torrents in the session are rejected rather than
sharing a handle between jobs.

Queue order controls which torrents run. Pausing frees a slot; resuming returns a
job to its existing queue position. `reorder(id, newIndex)` uses the final zero-based
position. `cancel` preserves files unless `deleteFiles: true` is requested while
the job is active. Completion and failure release download slots. Failed jobs can
be retried with `resume`. `clearHistory` removes terminal records, preserving files.
Progress counts selected files, not skipped content; libtorrent may still fetch
pieces overlapping selected and skipped files.

`configure(DownloadSettings(...))` changes concurrency, bandwidth, connection and
discovery limits in the running session. Seed slots are separate from download
slots. Seeding can be disabled (default), indefinite, or limited by both ratio and
elapsed time, following Senpwai's policy. Settings are supplied by the caller and
are not saved in the queue file. Defaults are used at app startup until a settings
consumer is connected.

Queue state lives in Sentorr's own `state/downloads.json`. It contains metadata,
selection, renames, status, seed start time, byte counts and terminal history.
Active jobs return to the queue on restart; explicit pauses remain paused. Existing
pieces are checked by libtorrent before downloading again. This intentionally does
not trust saved byte counts or use native fast-resume data. Upload totals survive
restart for seed-ratio accounting. Data files stay in the caller's destination,
independently of the player's evictable cache.

The runtime survives navigation and desktop close-to-tray. A Dart isolate does not
provide an Android foreground service or keep downloading after the process exits.
No download UI, notification bridge, or playback handoff is included.

## Validation

```sh
dart test test/downloads
flutter analyze --no-pub lib/downloads test/downloads
```

Queue tests cover promotion, pause/resume, reorder, cancellation, seeding slots,
retry, dynamic limits and restart persistence. Native tests transfer a fixture over
loopback from a separate libtorrent session, compare exact saved bytes, validate
selection/path rejection, and exercise the background isolate across restoration
and shutdown. These tests require the existing local libtorrent native asset.
They do not rely on public trackers or external peers.
