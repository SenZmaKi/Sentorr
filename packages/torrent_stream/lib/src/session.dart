import 'dart:async';

import 'config.dart';
import 'engine.dart';
import 'engine_models.dart';
import 'models.dart';
import 'source.dart';
import 'stream_state.dart';

/// One source and selected file, held in [engine] as its own owner, so a
/// torrent another owner holds (a download) keeps running after close.
/// Create before open so close can cancel metadata acquisition/preparation.
class TorrentStreamSession {
  TorrentStreamSession({required this.engine, required this.config})
    : owner = 'stream:${++_owners}' {
    _engineStates = engine.states.listen(_observe, onError: _onEngineError);
    if (engine.failure case final failure?) _fail(failure);
  }
  static var _owners = 0;
  final TorrentEngine engine;
  final TorrentStreamConfig config;

  /// This session's owner name in [engine].
  final String owner;
  late final StreamSubscription<List<TorrentSnapshot>> _engineStates;
  final _states = StreamController<TorrentStreamState>.broadcast();
  final _closing = Completer<void>();
  TorrentStreamState _state = const TorrentStreamState();
  TorrentStreamState get state => _state;
  Stream<TorrentStreamState> get states => _states.stream;
  String? _hash;
  Future<String?>? _adding;

  /// The torrent's info hash once open.
  String? get infoHash => _hash;
  TorrentStreamFile? _file;

  /// From open, which can return before the engine's next update has them.
  List<TorrentStreamFile> _files = const [];
  int? _stream;
  var _opened = false, _paused = false, _failed = false, _closed = false;
  Future<void>? _shutdown;

  void _publish(TorrentStreamState value) {
    _state = value;
    if (!_states.isClosed) _states.add(value);
  }

  void _at(TorrentStreamPhase phase) {
    final torrent = _hash == null ? null : engine.torrent(_hash!);
    _publish(
      torrent == null
          ? _state.atPhase(phase)
          : streamStateOf(
              torrent,
              phase: phase,
              transferPaused: _paused,
              selectedFile: _file,
              stream: _stream,
              previous: _state,
              files: _files,
            ),
    );
  }

  void _observe(List<TorrentSnapshot> torrents) {
    if (_failed || _closed || _hash == null) return;
    final torrent = torrents.where((t) => t.infoHash == _hash).firstOrNull;
    if (torrent == null) return;
    _publish(
      streamStateOf(
        torrent,
        phase: _state.phase,
        transferPaused: _paused,
        selectedFile: _file,
        stream: _stream,
        previous: _state,
        files: _files,
      ),
    );
  }

  void _onEngineError(Object error) {
    if (error is TorrentStreamException) _fail(error);
  }

  void _fail(TorrentStreamException error) {
    if (_closed || _failed) return;
    _failed = true;
    _publish(state.atPhase(TorrentStreamPhase.failed, failure: error));
  }

  void _check() {
    if (_closed || _closing.isCompleted || _failed) {
      throw const TorrentStreamException(
        TorrentStreamErrorCode.invalidState,
        'Session is closed, closing or failed',
      );
    }
  }

  /// [operation], unless close comes first.
  Future<T> _guard<T>(Future<T> operation) async {
    unawaited(operation.then((_) {}, onError: (Object _) {}));
    final closed = _closing.future.then<T>(
      (_) => throw const TorrentStreamException(
        TorrentStreamErrorCode.cancelled,
        'Session closed',
      ),
    );
    try {
      return await Future.any([operation, closed]);
    } on TorrentStreamException catch (error) {
      if (error.code != TorrentStreamErrorCode.invalidState &&
          !_closing.isCompleted) {
        _fail(error);
      }
      rethrow;
    }
  }

  Future<List<TorrentStreamFile>> open(
    TorrentSource source, {
    List<TorrentPeer> peers = const [],
  }) async {
    if (_opened) {
      throw const TorrentStreamException(
        TorrentStreamErrorCode.invalidState,
        'Open once per session',
      );
    }
    _check();
    _opened = true;
    _at(TorrentStreamPhase.acquiringMetadata);
    final retained = config.retainedDirectory;
    final adding = engine.add(
      source,
      owner: owner,
      directory: retained == null
          ? config.cacheDirectory
          : '${config.cacheDirectory}/$retained',
      storage: retained == null
          ? TorrentStorage.temporary
          : TorrentStorage.cached,
      peers: peers,
    );
    // Close may come while adding; the hold it creates is still released.
    _adding = adding.then<String?>((hash) => hash, onError: (Object _) => null);
    _hash = await _guard(adding);
    final files = await _guard(
      engine.metadata(_hash!, timeout: config.metadataTimeout),
    );
    _files = files;
    _at(TorrentStreamPhase.metadataReady);
    return files;
  }

  Future<TorrentStream> prepareFile(int index) async {
    final file = _files.where((f) => f.index == index).firstOrNull;
    if (file == null ||
        file.isPadFile ||
        file.length == 0 ||
        state.phase != TorrentStreamPhase.metadataReady) {
      throw const TorrentStreamException(
        TorrentStreamErrorCode.invalidState,
        'Select a nonempty non-pad file after metadata is ready',
      );
    }
    _check();
    _file = file;
    _at(TorrentStreamPhase.preparing);
    final stream = await _guard(
      engine.stream(_hash!, owner, index, options: config.streamOptions),
    );
    _stream = stream.id;
    _at(TorrentStreamPhase.serving);
    return TorrentStream(uri: stream.uri, file: file);
  }

  /// Supply newly discovered peers without restarting metadata or playback.
  Future<void> addPeers(List<TorrentPeer> peers) async {
    _check();
    if (_hash case final hash?) await engine.addPeers(hash, peers);
  }

  Future<void> prepareSeek() async {
    _check();
    if (_stream case final stream?) await engine.prepareSeek(stream);
  }

  /// Pauses this session's hold; another owner may keep the torrent going.
  Future<void> setTransferPaused(bool paused) async {
    _check();
    if (_hash case final hash?) {
      await engine.setPaused(hash, owner, paused);
      _paused = paused;
      _at(state.phase);
    }
  }

  /// Idempotent; endpoints become invalid. Never deletes the caller's cache root.
  Future<void> close() => _shutdown ??= _close();
  Future<void> _close() async {
    if (!_closing.isCompleted) _closing.complete();
    try {
      if (engine.failure case final failure?) throw failure;
      final hash = _hash ?? await _adding;
      if (hash != null) await engine.release(hash, owner);
    } finally {
      _closed = true;
      await _engineStates.cancel();
      _publish(state.atPhase(TorrentStreamPhase.closed));
      // A paused observer must not hold native/cache shutdown hostage.
      unawaited(_states.close());
    }
  }
}
