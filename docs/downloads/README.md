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

## Library

`lib/library/` turns "download this movie or episode" into a queued download
and remembers it by IMDb id in `state/library.json`. `downloadPlannerProvider`
finds a torrent (exact matches only for automatic downloads), holds it briefly
to read its metadata, picks the item's file as playback does, and queues it
renamed into the readable layout under the downloads folder (default
`~/Downloads/Sentorr`; the macOS sandbox has the downloads entitlement):

- `Movie (2024)/Movie (2024).mkv`
- `Series (2019)/Season 01/Series S01E03.mkv`

`offlineStateProvider(id)` joins an entry with its download for buttons:
not downloaded, planning, downloading (with progress), downloaded or failed.
Launch skips the torrent search for anything in the library; the player plays
a finished file from disk and streams a download in progress from its own
torrent and file, sharing the transfer. Removing an entry cancels its download
and deletes its file and emptied folders itself, since the engine's file
deletion would also remove other episodes downloaded from the same pack.

## Validation

```sh
flutter test test/downloads test/library
(cd packages/torrent_stream && dart test)
```

Queue tests cover file choice, renames, slots, pause/resume, reorder,
cancellation, seeding, yielding to playback, failures and restoration. Native
tests download exact bytes from a loopback libtorrent peer, share a torrent
between a stream and a download, and reject bad selections and escaping names.
The planner test downloads an episode from a loopback seed into the library
layout, resolves it to a local file and removes it with its folders.
They need the local libtorrent native asset, not public trackers or peers.
