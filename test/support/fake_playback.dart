import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:torrent_stream/torrent_stream.dart';

class FakePlayback extends PlatformPlayer {
  FakePlayback() : super(configuration: const PlayerConfiguration());

  final opened = <Media>[];
  final seeks = <Duration>[];
  bool failOpen = false, failStop = false;
  void Function()? onOpen, onStop;

  void emitError(String message) => errorController.add(message);

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    onOpen?.call();
    if (failOpen) throw StateError('open failed');
    opened.add(playable as Media);
    state = state.copyWith(playing: play, position: Duration.zero);
  }

  @override
  Future<void> stop() async {
    onStop?.call();
    if (failStop) throw StateError('stop failed');
    state = state.copyWith(playing: false, position: Duration.zero);
  }

  @override
  Future<void> seek(Duration duration) async {
    seeks.add(duration);
    state = state.copyWith(position: duration);
  }
}

class FakeStreamingEngine implements TorrentEngine {
  final updates = StreamController<List<TorrentSnapshot>>.broadcast();
  final owners = <String, String>{};
  final released = <String>[];
  final sources = <TorrentSource>[];
  Completer<void>? seekGate, resumeGate;
  bool failRelease = false;
  int _streams = 0;

  @override
  Future<void> start() async {}

  @override
  Stream<List<TorrentSnapshot>> get states => updates.stream;
  @override
  TorrentStreamException? get failure => null;
  @override
  TorrentSnapshot? torrent(String infoHash) => null;

  @override
  Future<String> add(
    TorrentSource source, {
    required String owner,
    required String directory,
    TorrentStorage storage = TorrentStorage.temporary,
    List<TorrentPeer> peers = const [],
  }) async {
    sources.add(source);
    final hash = switch (source) {
      TorrentMetadataSource(:final expectedInfoHash) => expectedInfoHash!,
      MagnetSource(:final uri) => uri.queryParameters['xt']!,
      _ => throw StateError('Unexpected source'),
    };
    owners[owner] = hash;
    return hash;
  }

  @override
  Future<List<TorrentStreamFile>> metadata(
    String infoHash, {
    Duration? timeout,
  }) async => const [
    TorrentStreamFile(
      index: 0,
      path: 'video.mkv',
      length: 1000,
      isPadFile: false,
    ),
  ];

  @override
  Future<TorrentEngineStream> stream(
    String infoHash,
    String owner,
    int index, {
    StreamOptions? options,
  }) async {
    final id = ++_streams;
    return TorrentEngineStream(id, Uri.parse('http://127.0.0.1/$id'));
  }

  @override
  Future<void> setPaused(String infoHash, String owner, bool paused) async {
    if (!paused) await resumeGate?.future;
  }

  @override
  Future<void> prepareSeek(int stream) async => seekGate?.future;

  @override
  Future<void> release(
    String infoHash,
    String owner, {
    bool deleteFiles = false,
  }) async {
    released.add(owner);
    owners.remove(owner);
    if (failRelease) throw StateError('release failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> settlePlayback() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
