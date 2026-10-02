import 'dart:async';

import 'package:logging/logging.dart';
import 'package:torrent_stream/torrent_stream.dart';

import 'models.dart';
import 'repository.dart';
import 'rules.dart';
import 'torrents.dart';

part 'batches.dart';
part 'attachments.dart';

final _log = Logger('sentorr.downloads');

/// Download policy over the shared torrent engine: queue order and slots,
/// seeding, pausing for playback and persistence. Each download holds its
/// torrent as its own owner, so a stream of the same torrent shares it.
class DownloadQueue {
  DownloadQueue(
    this.torrents,
    this.repository, {
    this.preparationTimeout = const Duration(seconds: 60),
  });
  final Duration preparationTimeout;
  final DownloadTorrents torrents;
  final DownloadRepository repository;
  final _items = <DownloadItem>[];

  /// Downloads whose torrent has its files chosen, by id.
  final _attached = <String>{};

  /// Whether each attached download's hold was last left running.
  final _running = <String, bool>{};

  /// Upload saved before this run, since the engine counts from each add.
  final _uploadBefore = <String, int>{};
  final _changes = StreamController<List<DownloadItem>>.broadcast();
  DownloadSettings settings = const DownloadSettings();
  Future<void> _tail = Future.value();
  int _sequence = 0;
  bool _disposed = false;
  Future<void>? _shutdown;

  List<DownloadItem> get items => List.unmodifiable(_items);
  Stream<List<DownloadItem>> get changes => _changes.stream;

  Future<void> initialize(DownloadSettings initial) => _serial(() async {
    initial.validate();
    settings = initial;
    _items.addAll(await repository.load());
    for (final item in _items) {
      if (item.status == DownloadStatus.preparing) _attach(item.id);
    }
    _log.info('Restored ${_items.length} downloads');
  });

  Future<String> enqueue(TorrentDownloadJob job) => _serial(() async {
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    if (repository.cancelledBatches.contains(job.batchId)) {
      throw StateError('Season download cancelled');
    }
    final paused = repository.pausedBatches.contains(job.batchId);
    _items.add(
      DownloadItem(
        id: id,
        job: job,
        status: paused ? DownloadStatus.paused : DownloadStatus.preparing,
      ),
    );
    _log.info('Queued ${job.title} ($id) to ${job.destinationDirectory}');
    if (!paused) _attach(id);
    await _commit();
    return id;
  });

  Future<void> pause(String id) => _serial(() async {
    final item = _item(id);
    if (item.status.isTerminal || item.status == DownloadStatus.paused) return;
    _log.info('Paused ${_name(item)}');
    if (!_attached.contains(id)) await _release(item);
    _replace(item.withStatus(DownloadStatus.paused));
    _reconcile();
    await _commit();
  });

  Future<void> resume(String id) => _serial(() async {
    final item = _item(id);
    if (item.status != DownloadStatus.paused &&
        item.status != DownloadStatus.failed) {
      return;
    }
    _log.info('Resumed ${_name(item)}');
    if (_attached.contains(id)) {
      _replace(item.withStatus(DownloadStatus.queued));
    } else {
      _replace(item.withStatus(DownloadStatus.preparing));
      _attach(id);
    }
    _reconcile();
    await _commit();
  });

  /// Keeps files unless [deleteFiles]; a stream of the torrent keeps
  /// running until it closes.
  Future<void> cancel(String id, {bool deleteFiles = false}) => _serial(
    () async {
      final item = _item(id);
      if (item.status.isTerminal) return;
      _log.info(
        'Cancelled ${_name(item)}${deleteFiles ? ', deleting its files' : ''}',
      );
      await _release(item, deleteFiles: deleteFiles);
      _replace(item.withStatus(DownloadStatus.cancelled));
      _reconcile();
      await _commit();
    },
  );

  Future<void> reorder(String id, int newIndex) => _serial(() async {
    final old = _index(id);
    if (newIndex < 0 || newIndex >= _items.length) {
      throw RangeError.index(newIndex, _items);
    }
    _items.insert(newIndex, _items.removeAt(old));
    _reconcile();
    await _commit();
  });

  /// Forgets finished, failed and cancelled downloads; files stay.
  Future<void> clearHistory() => _serial(() async {
    _items.removeWhere((i) => i.status.isTerminal);
    await _commit();
  });

  Future<void> configure(DownloadSettings next) => _serial(() async {
    next.validate();
    settings = next;
    _log.info(
      'Download settings: ${next.maxActiveDownloads} active, '
      '${next.maxActiveSeeds} seeding, seeding ${next.seedingMode.name}',
    );
    _reconcile();
    _publish();
  });

  /// Reads transfer progress from the engine and applies queue policy.
  Future<void> tick() => _serial(() async {
    var changed = false;
    for (final id in _attached.toList()) {
      final previous = _item(id);
      final torrent = _torrent(previous);
      if (torrent == null) continue;
      if (torrent.error case final error?) {
        _log.warning('${_name(previous)} failed: $error');
        await _release(previous);
        _replace(previous.withStatus(DownloadStatus.failed, error: error));
        changed = true;
        continue;
      }
      var next = progressOf(
        previous,
        torrent,
        uploadedBefore: _uploadBefore[id] ?? 0,
      );
      if (next.isDone && previous.status != DownloadStatus.paused) {
        next = await _finish(next);
      }
      changed |= next.status != previous.status;
      if (next.status != previous.status) {
        _log.info(
          '${_name(next)}: ${previous.status.name} → ${next.status.name}',
        );
      }
      _replace(next);
    }
    _reconcile();
    if (changed) {
      await _commit();
    } else {
      _publish();
    }
  });

  /// Seeds when settings ask, then completes and lets the torrent go.
  Future<DownloadItem> _finish(DownloadItem item) async {
    final started = item.seedingStartedAt ?? DateTime.now();
    final done = seedingDone(item, settings, started);
    if (!done) {
      return item.copyWith(
        status: item.seedingStartedAt == null
            ? DownloadStatus.seeding
            : item.status,
        seedingStartedAt: started,
      );
    }
    await _release(item);
    return item
        .copyWith(seedingStartedAt: started)
        .withStatus(DownloadStatus.completed);
  }

  /// Gives queue slots in order; a download being watched always runs, and
  /// while anything streams the others can wait.
  void _reconcile() {
    final watched = {
      for (final t in torrents.torrents)
        if (t.streams.isNotEmpty) t.infoHash,
    };
    final yieldToPlayback = settings.pauseWhileStreaming && watched.isNotEmpty;
    var downloads = settings.maxActiveDownloads;
    var seeds = settings.maxActiveSeeds;
    for (final item in _items.toList()) {
      if (!_attached.contains(item.id) ||
          item.status.isTerminal ||
          item.status == DownloadStatus.paused) {
        if (_attached.contains(item.id)) _hold(item, running: false);
        continue;
      }
      final isSeed = item.seedingStartedAt != null;
      final isWatched = watched.contains(item.infoHash);
      var allowed = isSeed ? seeds-- > 0 : downloads-- > 0;
      if (yieldToPlayback && !isWatched) allowed = false;
      if (isWatched) allowed = true;
      _hold(item, running: allowed);
      final status = !allowed
          ? DownloadStatus.queued
          : isSeed
          ? DownloadStatus.seeding
          : DownloadStatus.downloading;
      if (item.status != status) _replace(item.withStatus(status));
    }
  }

  void _hold(DownloadItem item, {required bool running}) {
    final hash = item.infoHash;
    if (hash == null || _running[item.id] == running) return;
    _running[item.id] = running;
    torrents.setPaused(hash, item.owner, !running).catchError((Object e) {
      _log.warning(
        'Could not ${running ? 'start' : 'pause'} ${_name(item)}',
        e,
      );
    });
  }

  Future<void> _release(DownloadItem item, {bool deleteFiles = false}) async {
    _attached.remove(item.id);
    _running.remove(item.id);
    final hash = item.infoHash;
    if (hash == null) return;
    try {
      await torrents
          .release(hash, item.owner, deleteFiles: deleteFiles)
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      _log.warning('Could not release ${_name(item)}', error);
    }
  }

  TorrentSnapshot? _torrent(DownloadItem item) =>
      torrents.torrents.where((t) => t.infoHash == item.infoHash).firstOrNull;

  int _index(String id) {
    final n = _items.indexWhere((i) => i.id == id);
    if (n < 0) throw ArgumentError('Unknown download: $id');
    return n;
  }

  DownloadItem _item(String id) => _items[_index(id)];
  void _replace(DownloadItem item) => _items[_index(item.id)] = item;

  void _publish() {
    if (!_changes.isClosed) _changes.add(items);
  }

  Future<void> _commit() async {
    _publish();
    await repository.save(items);
  }

  Future<void> flush() => _serial(() => repository.save(items));

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  String _name(DownloadItem item) => '${item.job.title} (${item.id})';

  /// Saves the queue; torrents stay in the engine for it to close.
  Future<void> dispose() => _shutdown ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await flush();
    // A paused UI subscription cannot deliver done until it resumes or is
    // cancelled. Bootstrap disposes those subscribers after closing the queue,
    // so waiting for them here would deadlock application shutdown.
    unawaited(_changes.close());
  }
}
