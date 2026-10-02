# Download queue

`lib/downloads/` is download policy over the shared torrent engine
(`packages/torrent_stream`, see its README and
[ARCHITECTURE.md](ARCHITECTURE.md)). It runs on the main isolate; the engine
isolate does every native call. App bootstrap restores the queue; lifecycle
flush and shutdown await its writes, then close the engine.

## Entry points

Read `downloadQueueProvider` for commands and `downloadsProvider` for snapshots.

```dart
final queue = ref.read(downloadQueueProvider);
final id = await queue.enqueue(TorrentDownloadJob(
  title: 'Movie',
  magnet: release.magnet,
  destinationDirectory: destination,
  selectedFileIndices: [0],
  renamedFiles: {0: 'Movie (2024).mkv'},
));
await queue.pause(id);
await queue.resume(id);
```

A job takes a magnet or `.torrent` metadata. It is **preparing** until metadata
arrives; then its selection is validated (empty means every non-padding file),
renames are applied inside the destination and its files are wanted. Invalid
selections fail the download and release its hold.

Each download holds its torrent as owner `download:<id>`. A stream of the same
torrent shares it: the download is never paused while watched, and the stream
keeps running if the download is paused or cancelled. While anything streams,
other downloads wait (`pauseWhileStreaming`, on by default).

Queue order controls which downloads run. Pausing frees a slot; resuming
returns a job to its queue position. `reorder(id, newIndex)` uses the final
zero-based position. `cancel` preserves files unless `deleteFiles: true`.
Completion and failure release slots and holds. Failed jobs retry with
`resume`. `clearHistory` removes terminal records, preserving files. Seeding
can be disabled (default), indefinite, or limited by both ratio and time, with
its own slots. Bandwidth, connections and discovery are engine settings,
shared with streaming.

Queue state lives in `state/downloads.json`: job, info hash, status, seed start,
byte counts, upload total and history. Unfinished downloads are re-added on
restart and libtorrent rechecks existing pieces; paused and finished ones stay
out of the engine. No native fast-resume data is used.

The queue survives navigation and desktop close-to-tray. It does not keep
downloading after the process exits or provide an Android foreground service.

## Validation

```sh
flutter test test/downloads
(cd packages/torrent_stream && dart test)
```

Queue tests cover file choice, renames, slots, pause/resume, reorder,
cancellation, seeding, yielding to playback, failures and restoration. Native
tests download exact bytes from a loopback libtorrent peer, share a torrent
between a stream and a download, and reject bad selections and escaping names.
They need the local libtorrent native asset, not public trackers or peers.
