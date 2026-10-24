import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:path/path.dart' as p;

import '../config.dart';
import '../engine_models.dart';
import 'cancellation.dart';
import 'diagnosis.dart';
import 'files.dart';
import 'resume_store.dart';
import 'native_session.dart';
import 'metadata_hash_cache.dart';
import 'tracker_policy.dart';
import 'snapshot_equality.dart';
import 'stream_host.dart';
import 'torrent_entry.dart';

part 'adds.dart';
part 'storage.dart';

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
  late final _hashes = MetadataHashCache(
    (bytes) => infoHashOf({'kind': 'bytes', 'value': bytes}),
  );
  List<TorrentSnapshot>? _published;
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
    final previous = _published;
    if (_torrents.isEmpty && previous != null && previous.isEmpty) return;
    final next = [for (final entry in _torrents.values) _snapshot(entry)];
    if (previous != null && previous.length == next.length) {
      var same = true;
      for (var i = 0; i < next.length; i++) {
        if (!sameSnapshot(previous[i], next[i])) {
          same = false;
          break;
        }
      }
      if (same) return;
    }
    _published = next;
    send({'kind': 'state', 'value': next});
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

  /// An on-demand look inside [hash] and, when given, one of its streams.
  Map<String, Object?> diagnose(String hash, int? stream) => diagnoseEntry(
    _entry(hash),
    stream == null ? null : _streams[stream]?.streams[stream],
    native.session,
  );

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
    entry.materialized.add(index);
    await entry.disk.exclusive(
      () => entry.applyWanted((ready) => waitUntil(entry.lifetime, ready)),
    );
    entry.lifetime.check();
    if (!entry.owners.containsKey(owner)) throw StateError('Not an owner');
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
  void prefetch(int id, int start, int end) {
    final host = _streams[id]?.streams[id];
    if (host == null) return;
    if (start < 0 || end <= start || end > host.file.size) {
      throw ArgumentError('Invalid prefetch range');
    }
    host.bytes.prefetch(start, end);
  }

  /// Sizes the stream's urgent window to its media bitrate.
  void pace(int id, int bytesPerSecond) {
    _streams[id]?.streams[id]?.bytes.pace(bytesPerSecond);
  }

  void seek(int id) {
    final host = _streams[id]?.streams[id];
    host?.server?.cancelReads();
    host?.bytes.restart();
  }

  Future<void> closeStream(int id) async {
    final entry = _streams.remove(id);
    final host = entry?.streams.remove(id);
    await host?.close();
    if (entry != null) publish();
  }

  /// Drops [owner] and its streams. The torrent leaves the session with its
  /// last owner, deleting its files when asked or when they were temporary.
  Future<void> release(String hash, String owner, {bool deleteFiles = false}) =>
      _serialize(hash, () => _release(hash, owner, deleteFiles: deleteFiles));

  Future<void> _release(
    String hash,
    String owner, {
    required bool deleteFiles,
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
    entry.lifetime.cancel();
    for (final stream in entry.streams.values.toList()) {
      await closeStream(stream.id);
    }
    // Cancelled reads can still be closing their OS handles. Drain them before
    // native removal/deletion, particularly on Windows.
    await entry.disk.exclusive(() async {});
    final temporary = entry.storage == TorrentStorage.temporary;
    if (!temporary && !deleteFiles && entry.files.isNotEmpty) {
      try {
        entry.handle.pause();
        await saveResume(entry);
      } catch (error) {
        // Persistence failure must not strand native handles at shutdown.
        stderr.writeln('Could not save torrent resume state: $error');
      }
    }
    try {
      entry.handle.pause();
      native.session.removeTorrent(
        entry.handle,
        deleteFiles: deleteFiles || temporary,
      );
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (native.session.getTorrents().any((h) => h.id == entry.handle.id)) {
        if (DateTime.now().isAfter(deadline)) {
          throw TimeoutException('Removing torrent ${entry.infoHash}');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    } on TimeoutException {
      // Keep the canceled entry reserved; an add must not reuse native storage
      // whose removal has not been confirmed.
      rethrow;
    } catch (_) {
      // A failed handle is already gone from libtorrent's point of view.
    }
    _torrents.remove(entry.infoHash);
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
