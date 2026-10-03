# torrent_stream

A pure Dart torrent engine: **one libtorrent session → verified pieces → loopback HTTP ranges**, plus full downloads. It has no Sentorr, Flutter, MediaKit, Riverpod, catalog or app-directory dependency. Sentorr plays through it from `lib/player/stream/` and downloads through it from `lib/downloads/`.

## Engine

`TorrentEngine` owns one native session in the package's worker isolate. The binding has process-wide registries, so every native call stays on that worker; create one engine per app.

- Torrents are shared by info hash between **owners** the caller names (`download:42`, `stream:7`). The last `release` removes the torrent.
- `want(hash, owner, files)` downloads files in full at normal priority; the torrent fetches the union of its owners' wants and nothing else.
- `stream(hash, owner, index)` serves a file over loopback HTTP. Reads raise priority and set deadlines just ahead of themselves, then return pieces to their base priority, so streaming a file that is downloading only adds urgency.
- Storage ranks `temporary < cached < kept`. Adding an owner with longer-lasting storage moves the torrent there (`moveStorage`); temporary folders are deleted when emptied or when the torrent leaves.
- A torrent pauses only when every owner pauses it.
- `configure` changes session-wide limits, transport and discovery while running.

```dart
final engine = TorrentEngine();
final hash = await engine.add(source, owner: 'download:1',
    directory: downloads, storage: TorrentStorage.kept);
final files = await engine.metadata(hash);
await engine.want(hash, 'download:1', {files.first.index});
```

## Stream sessions

`TorrentStreamSession` is one owner streaming one file, the player's view of the engine:

```dart
final session = TorrentStreamSession(
  engine: engine,
  config: TorrentStreamConfig(cacheDirectory: applicationCacheRoot),
);
try {
  final files = await session.open(TorrentSource.magnet(resolvedMagnet));
  // The resolver/application chooses a file explicitly, including TV episodes.
  final endpoint = await session.prepareFile(chosenFileIndex);
  await player.open(endpoint.uri); // Consumer-specific player operation.
  // Before a coordinated seek:
  await session.prepareSeek();
  await player.seek(targetPosition);
} finally {
  // Stop/disconnect the player before invalidating its endpoint.
  await session.close();
}
```

`player` above is illustrative; no player interface is imposed by this package. Any local HTTP range client can use the endpoint. A client that does not coordinate seeks still benefits from disconnect cancellation. The optional `peers` argument to `open`, or `addPeers`, accepts explicit discovered IP/port peers. Sources can also be a `.torrent` file or copied torrent metadata bytes.

Create the session **before** starting `open`: `close` must remain available while metadata or initial bytes are pending. Open once, prepare one file, close idempotently. Use another session to change source/file. `state` provides a current immutable snapshot; `states` is a broadcast stream of subsequent changes. It describes transfer state, not player buffering or decoded readiness. `setTransferPaused` pauses this session's hold; another owner may keep the torrent running.

Without `retainedDirectory` a session saves into a temporary child of the cache root, deleted on close; with it, into that named child, kept. Closing releases only the session's hold, so a download of the same torrent continues. There is no rolling disk quota, background foreground-service runtime or automatic file selection.

After a real pause libtorrent waits before reconnecting peers it dropped (five seconds per failure here); torrents with trackers or DHT also reannounce on resume. Rate limits follow libtorrent's defaults and do not throttle peers on the local network.

## Player telemetry

`session.state` and `session.states` expose download/upload payload speeds in **bytes per second**, cumulative received/uploaded payload bytes, connected peers/seeds, known peers, connections (including pending handshakes), eligible connection candidates, native transfer activity, selected file and verified selected-file progress. Updates arrive approximately every 500 ms and at lifecycle transitions. Connected seeds are a subset of connected peers; known peers can include disconnected or banned peers. These are local observations, not tracker estimates of the entire swarm.

`verifiedBytes` (the existing `downloadedBytes`) measures available verified torrent data. `receivedBytes` measures network payload and can include retransmissions or bytes awaiting verification. `selectedProgress` measures the selected file, not playable seconds. Final totals remain available after close; active rates/connections become zero.

A MediaKit player overlay subscribes directly to this stream. MediaKit continues to supply playback position/buffering; torrent statistics do not need to pass through its decoder. For example, in a Flutter consumer:

```dart
StreamBuilder<TorrentStreamState>(
  stream: session.states,
  initialData: session.state,
  builder: (context, snapshot) {
    final transfer = snapshot.data!;
    return Text(
      'Peers ${transfer.connectedPeers} · Seeds ${transfer.connectedSeeds} '
      '↓ ${transfer.downloadBytesPerSecond} B/s '
      '↑ ${transfer.uploadBytesPerSecond} B/s',
    );
  },
)
```

Place this widget in the player controls/overlay; the core remains player independent. `example/serve.dart` demonstrates the same subscription without Flutter.

## Native prerequisite

This package uses the published `libtorrent_dart` 1.1.0 release, which includes the verified piece-read APIs and matching native bridge binaries. The binding's build hook downloads the binary for the target platform automatically; a sibling checkout or dependency override is unnecessary.

Run `dart pub get`, `dart analyze`, and `dart test`. For native binding development, use its `docs/BUILD.md` and this package's `tool/build_native.py` with an explicit local `pubspec_overrides.yaml`. Remove that override to verify the published release.

## Policy

Defaults are explicit configuration, with no environment-variable behavior: 5,000,000 bytes/second (40 Mbps) download cap; 16 MiB lookahead target; 24 MiB owned-piece LRU; 60-second metadata, 45-second piece and 15-second native-read waits; verified head/tail preparation; TCP-only peer transport. Zero download limit is unlimited. Mixed TCP/uTP is available through `TorrentTransport.mixedTcpUtp`; TCP-only is the demonstrated local audit baseline and can exclude uTP-only peers.

Only the currently needed piece is urgent; lookahead has ordinary priority. Full piece verification remains mandatory, even for a tiny HTTP range. Read-ahead is a target and can exceed its byte budget for large pieces. The LRU limit excludes native/player/socket buffers. Pieces larger than the LRU budget are not retained and may require repeated native reads; unusually large-piece torrents need additional performance validation.

DHT/tracker discovery remains enabled. Local-service discovery is disabled to avoid the self-discovery/replacement behavior observed with loopback known peers. Each package session has independent native torrent/server/cache ownership, while all package-owned FFI calls share one worker. **Create all sessions in one owner Dart isolate.** The binding's process-wide registries are not generally safe for concurrent calls from unrelated isolates; direct native-binding clients must not compete with this runtime. Multi-owner-isolate coordination requires binding/runtime work before it is supported.

The endpoint binds only loopback with an unpredictable path and ephemeral port. It supports single/suffix/open-ended ranges, HEAD, backpressure, bounded requests and cancellation. A read failure after HTTP headers aborts the socket; it never supplies unverified bytes, zeros or false EOF. The player observes HTTP read errors; transfer state reports fatal startup/native errors separately. Keep `close` in a `finally` path after failures. Abrupt process/worker termination can leave native jobs or temporary data; normal close provides the tested cleanup path.

## MediaKit later

The core endpoint means container-probe **bytes** are verified, not that ten seconds of video are playable. A MediaKit adapter should configure a ten-second playable-cache gate, sixty-second forward cache and **sixty-second HTTP timeout** before opening. Its HTTP timeout should exceed the engine's piece wait. It then observes actual demuxer cache/cache pause and position progression.

Mute, video/audio tracks, subtitles, playback pause, time-based seeking, buffering UI and player disposal belong to the consumer. The adapter calls `prepareSeek` before `Player.seek` and closes the engine after stopping player reads. This package never owns/disposes a player's object. See the [design](../../docs/Torrent/torrent-playback-engine.md) and [audit](../../tool/streaming_lab/FINAL_AUDIT.md).

## Evidence

On macOS: clean analysis; fourteen passing tests including a real seeded torrent, exact HTTP bytes, download pause, seed interruption/recovery, metadata/preparation cancellation, independent sessions preservation of caller/source files, paused state observers and unexpected worker exit. Tests run native files sequentially because their owner isolates differ; concurrency inside one owner is exercised explicitly. HTTP tests cover ranges and blocked-reader disconnect/seek cancellation.

No Sentorr app wiring or MediaKit playback audit of this package has been performed. The lab's prior playback results validate the approach, not this extraction's player integration. Windows/Linux/mobile runtimes and packaging remain unverified.
