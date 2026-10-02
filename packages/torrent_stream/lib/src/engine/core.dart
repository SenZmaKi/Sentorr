import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';

import '../config.dart';
import '../engine_models.dart';
import 'cancellation.dart';
import 'files.dart';
import 'native_session.dart';
import 'stream_host.dart';
import 'torrent_entry.dart';

/// The engine isolate's one session and every torrent in it. Commands may
/// interleave; each leaves the entries consistent at its awaits.
class EngineCore {
  EngineCore(TorrentEngineSettings settings, this.send)
    : native = NativeSession(settings) {
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => publish(),
    );
  }
  final NativeSession native;
  final void Function(Map<String, Object?>) send;
  final _torrents = <String, TorrentEntry>{};
  final _streams = <int, TorrentEntry>{};
  final lifetime = Cancellation();
  late final Timer _timer;
  int _streamIds = 0;
  bool _closed = false;

  void configure(TorrentEngineSettings settings) => native.configure(settings);

  /// Sends every torrent's state; a torrent whose handle fails is reported
  /// with its error and left for its owners to release.
  void publish() {
    if (_closed) return;
    send({
      'kind': 'state',
      'value': [for (final entry in _torrents.values) _snapshot(entry)],
    });
  }

  TorrentSnapshot _snapshot(TorrentEntry entry) {
    try {
      return entry.snapshot();
    } catch (error) {
      final last = entry.describe();
      return TorrentSnapshot(
        infoHash: last.infoHash,
        savePath: last.savePath,
        storage: last.storage,
        owners: last.owners,
        files: last.files,
        wanted: last.wanted,
        fileBytes: last.fileBytes,
        error: '$error',
      );
    }
  }

  TorrentEntry _entry(String hash) =>
      _torrents[hash] ?? (throw StateError('No torrent $hash'));

  /// Adds [source] for [owner], or adds [owner] to the torrent already
  /// holding its info hash. Returns that hash.
  Future<String> add(
    Map source, {
    required String owner,
    required String directory,
    required TorrentStorage storage,
    required List peers,
  }) async {
    lifetime.check();
    final hash = await infoHashOf(source);
    final known = _torrents[hash];
    if (known != null) {
      known.owners.putIfAbsent(owner, TorrentOwner.new);
      if (storage.index > known.storage.index) {
        await _move(known, directory, storage);
      }
      known.applyPause();
      _addPeers(known, peers);
      return hash;
    }
    final root = Directory(directory);
    await root.create(recursive: true);
    final Directory save;
    final temporary = storage == TorrentStorage.temporary;
    save = temporary ? await root.createTemp('torrent-stream-') : root;
    // Another add of the same hash may have finished while the folder was made.
    if (_torrents[hash] case final raced?) {
      if (temporary) await save.delete(recursive: true);
      raced.owners.putIfAbsent(owner, TorrentOwner.new);
      raced.applyPause();
      return hash;
    }
    final session = native.session;
    final handle = switch (source['kind']) {
      'magnet' => session.addMagnet(
        magnetUri: source['value'] as String,
        savePath: save.path,
      ),
      'file' => session.addTorrentFile(
        torrentPath: source['value'] as String,
        savePath: save.path,
      ),
      'bytes' => session.addTorrentData(
        torrentData: source['value'] as Uint8List,
        savePath: save.path,
      ),
      _ => throw ArgumentError('Unsupported torrent source'),
    };
    handle.setFlags(LibtorrentTorrentFlags.defaultDontDownload);
    handle.unsetFlags(
      LibtorrentTorrentFlags.autoManaged | LibtorrentTorrentFlags.paused,
    );
    final entry = TorrentEntry(
      infoHash: hash,
      handle: handle,
      savePath: save.path,
      storage: storage,
    );
    if (temporary) entry.temporary.add(save);
    entry.owners[owner] = TorrentOwner();
    _torrents[hash] = entry;
    entry.applyPause();
    _addPeers(entry, peers);
    // Owners wait for metadata through [metadata]; failures surface there.
    unawaited(
      entry.prepare((ready) => waitUntil(entry.lifetime, ready)).catchError((
        Object error,
        StackTrace stack,
      ) {
        if (!entry.ready.isCompleted) entry.ready.completeError(error, stack);
      }),
    );
    unawaited(entry.ready.future.catchError((Object _) {}));
    publish();
    return hash;
  }

  /// The torrent's files, once its metadata arrives within [timeout].
  Future<List<Map<String, Object?>>> metadata(
    String hash,
    Duration? timeout,
  ) async {
    final entry = _entry(hash);
    var ready = entry.lifetime.wait(entry.ready.future);
    if (timeout != null) {
      ready = ready.timeout(
        timeout,
        onTimeout: () => throw TimeoutException('Torrent metadata'),
      );
    }
    await ready;
    return [
      for (final f in entry.files)
        {
          'index': f.index,
          'path': f.path,
          'length': f.size,
          'pad': (f.flags & 1) != 0,
        },
    ];
  }

  Future<void> want(String hash, String owner, Set<int> files) async {
    final entry = _entry(hash);
    await entry.lifetime.wait(entry.ready.future);
    if (files.any((i) => i < 0 || i >= entry.files.length)) {
      throw ArgumentError('Unknown file index');
    }
    final holder = entry.owners[owner] ?? (throw StateError('Not an owner'));
    holder.wanted
      ..clear()
      ..addAll(files);
    await entry.applyWanted((ready) => waitUntil(entry.lifetime, ready));
    publish();
  }

  void pause(String hash, String owner, bool paused) {
    final entry = _entry(hash);
    final holder = entry.owners[owner] ?? (throw StateError('Not an owner'));
    holder.paused = paused;
    entry.applyPause();
    publish();
  }

  /// Renames files relative to the save path; names must stay inside it.
  Future<void> rename(String hash, Map<int, String> names) async {
    final entry = _entry(hash);
    await entry.lifetime.wait(entry.ready.future);
    for (final MapEntry(key: index, value: name) in names.entries) {
      final parts = name.split(RegExp(r'[\\/]'));
      if (index < 0 ||
          index >= entry.files.length ||
          name.isEmpty ||
          File(name).isAbsolute ||
          parts.any((p) => p == '..' || p.isEmpty)) {
        throw ArgumentError('File names must stay within the save directory');
      }
      entry.handle.renameFile(index, name);
    }
  }

  /// Moves the torrent's files to [directory], kept as [storage].
  Future<void> move(String hash, String directory, TorrentStorage storage) =>
      _move(_entry(hash), directory, storage);

  Future<void> _move(
    TorrentEntry entry,
    String directory,
    TorrentStorage storage,
  ) async {
    if (storage == TorrentStorage.temporary) {
      throw ArgumentError('Torrents move only into caller folders');
    }
    await Directory(directory).create(recursive: true);
    if (entry.savePath != directory) entry.handle.moveStorage(directory);
    entry.savePath = directory;
    entry.storage = storage;
    final left = [...entry.temporary];
    entry.temporary.clear();
    for (final folder in left) {
      unawaited(deleteWhenEmptied(folder));
    }
    publish();
  }

  void addPeers(String hash, List peers) => _addPeers(_entry(hash), peers);

  void _addPeers(TorrentEntry entry, List peers) => entry.connect(peers);

  /// Serves [index] over loopback HTTP for [owner]; returns its id and URL.
  Future<List<Object>> stream(
    String hash,
    String owner,
    int index,
    StreamOptions options,
  ) async {
    final entry = _entry(hash);
    await entry.lifetime.wait(entry.ready.future);
    if (!entry.owners.containsKey(owner)) throw StateError('Not an owner');
    final file = entry.files.firstWhere(
      (f) => f.index == index,
      orElse: () => throw ArgumentError('Unknown file index'),
    );
    if (file.size == 0 || (file.flags & 1) != 0) {
      throw ArgumentError('Select a nonempty, non-pad file');
    }
    final id = ++_streamIds;
    final host = StreamHost.open(id, owner, entry, file, native, options);
    entry.streams[id] = host;
    _streams[id] = entry;
    publish();
    try {
      return [id, await host.start(options.prepareContainer)];
    } catch (_) {
      await closeStream(id);
      rethrow;
    }
  }

  /// Cancels the stream's pending reads before a seek.
  void seek(int id) {
    _streams[id]?.streams[id]?.server?.cancelReads();
  }

  Future<void> closeStream(int id) async {
    final entry = _streams.remove(id);
    final host = entry?.streams.remove(id);
    await host?.close();
    if (entry != null) publish();
  }

  /// Drops [owner] and its streams. The torrent leaves the session with its
  /// last owner, deleting its files when asked or when they were temporary.
  Future<void> release(
    String hash,
    String owner, {
    bool deleteFiles = false,
  }) async {
    final entry = _torrents[hash];
    if (entry == null) return;
    for (final stream in entry.streams.values.toList()) {
      if (stream.owner == owner) await closeStream(stream.id);
    }
    entry.owners.remove(owner);
    if (entry.owners.isNotEmpty) {
      entry.applyPause();
      await entry.applyWanted((ready) => waitUntil(entry.lifetime, ready));
      publish();
      return;
    }
    await _remove(entry, deleteFiles: deleteFiles);
    publish();
  }

  Future<void> _remove(TorrentEntry entry, {required bool deleteFiles}) async {
    _torrents.remove(entry.infoHash);
    entry.lifetime.cancel();
    for (final stream in entry.streams.values.toList()) {
      await closeStream(stream.id);
    }
    final temporary = entry.storage == TorrentStorage.temporary;
    try {
      entry.handle.pause();
      native.session.removeTorrent(
        entry.handle,
        deleteFiles: deleteFiles || temporary,
      );
    } catch (_) {
      // A failed handle is already gone from libtorrent's point of view.
    }
    for (final folder in entry.temporary) {
      await deleteSoon(folder);
    }
  }

  Future<void> close() async {
    if (_closed) return;
    lifetime.cancel();
    for (final entry in _torrents.values.toList()) {
      await _remove(entry, deleteFiles: false);
    }
    _closed = true;
    _timer.cancel();
    await native.close();
  }
}
