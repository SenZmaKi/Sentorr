import 'dart:async';
import 'package:test/test.dart';
import 'package:torrent_stream/torrent_stream.dart';

class BufferEngine implements TorrentEngine {
  final ranges = <(int, int)>[];
  @override
  TorrentStreamException? get failure => null;
  @override
  Stream<List<TorrentSnapshot>> get states => const Stream.empty();
  @override
  TorrentSnapshot? torrent(String hash) => null;
  @override
  Future<String> add(
    TorrentSource source, {
    required String owner,
    required String directory,
    TorrentStorage storage = TorrentStorage.temporary,
    List<TorrentPeer> peers = const [],
  }) async => 'hash';
  @override
  Future<List<TorrentStreamFile>> metadata(
    String hash, {
    Duration? timeout,
  }) async => [
    const TorrentStreamFile(
      index: 0,
      path: 'video.mkv',
      length: 6000000,
      isPadFile: false,
    ),
  ];
  @override
  Future<TorrentEngineStream> stream(
    String hash,
    String owner,
    int index, {
    StreamOptions? options,
  }) async => TorrentEngineStream(1, Uri.parse('http://localhost/video'));
  @override
  Future<void> prefetch(int stream, int start, int end) async {
    ranges.add((start, end));
  }

  @override
  Future<void> release(
    String hash,
    String owner, {
    bool deleteFiles = false,
  }) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('time window follows playback and scales with media duration', () async {
    final engine = BufferEngine();
    final session = TorrentStreamSession(
      engine: engine,
      config: TorrentStreamConfig(
        cacheDirectory: '/tmp/buffer',
        downloadAheadMinutes: 10,
      ),
    );
    await session.open(
      TorrentSource.magnet(Uri.parse('magnet:?xt=urn:btih:hash')),
    );
    await session.prepareFile(0);
    await session.bufferAhead(Duration.zero, Duration.zero);
    expect(engine.ranges, isEmpty);
    await session.bufferAhead(
      const Duration(minutes: 5),
      const Duration(minutes: 60),
    );
    expect(engine.ranges.last, (500000, 1500000));
    await session.bufferAhead(
      const Duration(minutes: 55),
      const Duration(minutes: 60),
    );
    expect(engine.ranges.last, (5500000, 6000000));
    await session.close();
  });
  test('entire file does not need duration or advancing playback', () async {
    final engine = BufferEngine();
    final session = TorrentStreamSession(
      engine: engine,
      config: TorrentStreamConfig(
        cacheDirectory: '/tmp/buffer',
        downloadAheadMinutes: 0,
      ),
    );
    await session.open(
      TorrentSource.magnet(Uri.parse('magnet:?xt=urn:btih:hash')),
    );
    await session.prepareFile(0);
    await session.bufferAhead(Duration.zero, Duration.zero);
    expect(engine.ranges.single, (0, 6000000));
    await session.close();
  });
}
