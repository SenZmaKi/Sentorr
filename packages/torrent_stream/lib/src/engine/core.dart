import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:path/path.dart' as p;

import '../config.dart';
import '../engine_models.dart';
import 'cancellation.dart';
import 'files.dart';
import 'native_session.dart';
import 'tracker_policy.dart';
import 'stream_host.dart';
import 'torrent_entry.dart';

part 'adds.dart';

/// The engine isolate's one session and every torrent in it. Commands may
/// interleave; each leaves the entries consistent at its awaits.
class EngineCore {
  EngineCore(TorrentEngineSettings settings, this.send)
    : native = NativeSession(settings),
      _defaultTrackers = List.unmodifiable(settings.defaultTrackers) {
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => publish(),
    );
  }
  final NativeSession native;
  List<String> _defaultTrackers;
  final void Function(Map<String, Object?>) send;
  final _torrents = <String, TorrentEntry>{};
  final _adds = <String, Future<void>>{};
  final _streams = <int, TorrentEntry>{};
  final lifetime = Cancellation();
  late final Timer _timer;
  int _streamIds = 0;
  bool _closed = false;

  void configure(TorrentEngineSettings settings) {
    native.configure(settings);
    _defaultTrackers = List.unmodifiable(settings.defaultTrackers);
  }

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

  Future<void> pause(String hash, String owner, bool paused) async {
    final entry = _entry(hash);
    final holder = entry.owners[owner] ?? (throw StateError('Not an owner'));
    holder.paused = paused;
    entry.applyPause();
    await entry.applyWanted((ready) => waitUntil(entry.lifetime, ready));
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
