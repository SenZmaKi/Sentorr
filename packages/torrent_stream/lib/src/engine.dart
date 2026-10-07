import 'dart:async';
import 'dart:isolate';

import 'config.dart';
import 'engine_models.dart';
import 'models.dart';
import 'native_runtime.dart';
import 'source.dart';

/// One libtorrent session for every torrent, streamed or downloaded, run in
/// the package's native isolate. Torrents are shared by info hash between
/// owners, which callers name, e.g. `download:42` or `stream:7`.
class TorrentEngine {
  TorrentEngine({
    TorrentEngineSettings settings = const TorrentEngineSettings(),
  }) : _settings = settings {
    settings.validate();
    _messages.listen(_receive);
    _runtime = NativeRuntime.acquire(_fail);
  }
  TorrentEngineSettings _settings;
  final _messages = ReceivePort();
  late final NativeRuntime _runtime;
  final _pending = <int, Completer<Object?>>{};
  final _states = StreamController<List<TorrentSnapshot>>.broadcast();
  Future<SendPort>? _started;
  Future<void>? _shutdown;
  TorrentStreamException? _failure;
  var _sequence = 0, _closed = false;
  List<TorrentSnapshot> _torrents = const [];

  /// Every torrent, as of the latest update, about twice a second.
  List<TorrentSnapshot> get torrents => _torrents;
  Stream<List<TorrentSnapshot>> get states => _states.stream;
  TorrentStreamException? get failure => _failure;

  TorrentSnapshot? torrent(String infoHash) =>
      _torrents.where((t) => t.infoHash == infoHash).firstOrNull;

  void _receive(dynamic raw) {
    final message = raw as Map;
    switch (message['kind']) {
      case 'state':
        _torrents = List.unmodifiable(
          (message['value'] as List).cast<TorrentSnapshot>(),
        );
        if (!_states.isClosed) _states.add(_torrents);
      case 'reply':
        final pending = _pending.remove(message['id']);
        if (pending == null) return;
        if (message.containsKey('code')) {
          pending.completeError(
            TorrentStreamException(
              TorrentStreamErrorCode.values[message['code'] as int],
              message['message'] as String,
            ),
          );
        } else {
          pending.complete(message['result']);
        }
    }
  }

  void _fail(TorrentStreamException error) {
    if (_closed || _failure != null) return;
    _failure = error;
    for (final pending in _pending.values) {
      if (!pending.isCompleted) pending.completeError(error);
    }
    _pending.clear();
    if (!_states.isClosed) _states.addError(error);
  }

  Future<SendPort> _start() => _started ??= () async {
    final port = await _runtime.ready;
    await _send(port, 'start', {'settings': _settings});
    return port;
  }();

  Future<Object?> _send(SendPort port, String op, Map<String, Object?> args) {
    if (_failure case final failure?) throw failure;
    final id = ++_sequence;
    final reply = Completer<Object?>();
    _pending[id] = reply;
    port.send({'host': _messages.sendPort, 'id': id, 'op': op, ...args});
    return reply.future;
  }

  Future<Object?> _command(
    String op, [
    Map<String, Object?> args = const {},
  ]) async {
    if (_closed) {
      throw const TorrentStreamException(
        TorrentStreamErrorCode.invalidState,
        'Engine is closed',
      );
    }
    if (_failure case final failure?) throw failure;
    return _send(await _start(), op, args);
  }

  /// Initialize discovery while a caller fetches HTTP torrent metadata.
  Future<void> start() async {
    if (_closed) {
      throw const TorrentStreamException(
        TorrentStreamErrorCode.invalidState,
        'Engine is closed',
      );
    }
    await _start();
  }

  /// Changes limits and discovery for every torrent.
  Future<void> configure(TorrentEngineSettings settings) async {
    settings.validate();
    _settings = settings;
    if (_started != null) await _command('configure', {'settings': settings});
  }

  /// Holds [source] for [owner] and returns its info hash. A torrent already
  /// in the engine gains the owner instead, moving to [directory] when
  /// [storage] outlasts its own. Temporary torrents get a child of [directory].
  Future<String> add(
    TorrentSource source, {
    required String owner,
    required String directory,
    TorrentStorage storage = TorrentStorage.temporary,
    List<TorrentPeer> peers = const [],
  }) async =>
      await _command('add', {
            'source': switch (source) {
              MagnetSource() => {
                'kind': 'magnet',
                'value': source.uri.toString(),
              },
              TorrentFileSource() => {'kind': 'file', 'value': source.path},
              TorrentMetadataSource() => {
                'kind': 'bytes',
                'value': source.bytes,
                'expectedHash': source.expectedInfoHash,
                'trackers': source.trackers
                    .map((uri) => uri.toString())
                    .toList(),
              },
            },
            'owner': owner,
            'directory': directory,
            'storage': storage,
            'peers': _peers(peers),
          })
          as String;

  /// The torrent's files once metadata arrives; [timeout] null waits on.
  Future<List<TorrentStreamFile>> metadata(
    String infoHash, {
    Duration? timeout,
  }) async {
    final files =
        await _command('metadata', {'hash': infoHash, 'timeout': timeout})
            as List;
    return List.unmodifiable([
      for (final f in files.cast<Map>())
        TorrentStreamFile(
          index: f['index'] as int,
          path: f['path'] as String,
          length: f['length'] as int,
          isPadFile: f['pad'] as bool,
        ),
    ]);
  }

  /// Files [owner] wants downloaded in full, replacing its earlier choice.
  Future<void> want(String infoHash, String owner, Set<int> files) async {
    await _command('want', {
      'hash': infoHash,
      'owner': owner,
      'files': Set<int>.of(files),
    });
  }

  /// The torrent pauses only while every owner pauses it.
  Future<void> setPaused(String infoHash, String owner, bool paused) async {
    await _command('pause', {
      'hash': infoHash,
      'owner': owner,
      'paused': paused,
    });
  }

  /// Renames files by index, relative to the save folder.
  Future<void> rename(String infoHash, Map<int, String> names) async {
    await _command('rename', {'hash': infoHash, 'names': Map.of(names)});
  }

  Future<void> move(
    String infoHash,
    String directory, {
    TorrentStorage storage = TorrentStorage.kept,
  }) async {
    await _command('move', {
      'hash': infoHash,
      'directory': directory,
      'storage': storage,
    });
  }

  Future<void> addPeers(String infoHash, List<TorrentPeer> peers) async {
    await _command('peers', {'hash': infoHash, 'peers': _peers(peers)});
  }

  /// Serves file [index] over loopback HTTP; reads raise the priority of
  /// the pieces just ahead of them.
  Future<TorrentEngineStream> stream(
    String infoHash,
    String owner,
    int index, {
    StreamOptions? options,
  }) async {
    final result =
        await _command('stream', {
              'hash': infoHash,
              'owner': owner,
              'index': index,
              'options': options ?? StreamOptions(),
            })
            as List;
    return TorrentEngineStream(
      result[0] as int,
      Uri.parse(result[1] as String),
    );
  }

  /// Cancels a stream's pending reads before its player seeks.
  Future<void> prefetch(int stream, int start, int end) async {
    await _command('prefetch', {'stream': stream, 'start': start, 'end': end});
  }

  Future<void> prepareSeek(int stream) async {
    await _command('seek', {'stream': stream});
  }

  Future<void> closeStream(int stream) async {
    await _command('closeStream', {'stream': stream});
  }

  /// Drops [owner]'s hold and streams; the last owner removes the torrent.
  Future<void> release(
    String infoHash,
    String owner, {
    bool deleteFiles = false,
  }) async {
    await _command('release', {
      'hash': infoHash,
      'owner': owner,
      'delete': deleteFiles,
    });
  }

  /// Removes every torrent, keeping non-temporary files. Idempotent.
  Future<void> close() => _shutdown ??= _close();
  Future<void> _close() async {
    try {
      if (_started != null && _failure == null) {
        await _send(await _started!, 'close', {});
      }
    } finally {
      _closed = true;
      _runtime.release(_fail);
      const error = TorrentStreamException(
        TorrentStreamErrorCode.cancelled,
        'Engine closed',
      );
      for (final pending in _pending.values) {
        if (!pending.isCompleted) pending.completeError(error);
      }
      _pending.clear();
      _messages.close();
      unawaited(_states.close());
    }
  }

  static List<Map<String, Object>> _peers(List<TorrentPeer> peers) => [
    for (final p in peers) {'address': p.address, 'port': p.port},
  ];
}

class TorrentEngineStream {
  const TorrentEngineStream(this.id, this.uri);
  final int id;
  final Uri uri;
}
