import 'backend.dart';
import 'models.dart';
import 'repository.dart';

/// Torrent-only queue adapted from Senpwai's in-process download runtime.
/// The isolate serializes commands and polling; native handles never leave it.
class DownloadEngine {
  DownloadEngine(this.backend, this.repository);
  final DownloadBackend backend;
  final DownloadRepository repository;
  final _items = <DownloadItem>[];
  final _transfers = <String, DownloadTransfer>{};
  DownloadSettings settings = const DownloadSettings();
  List<DownloadItem> get items => List.unmodifiable(_items);
  int _sequence = 0;

  Future<void> initialize(DownloadSettings initial) async {
    settings = initial;
    backend.configure(initial);
    _items.addAll(await repository.load());
    for (var n = 0; n < _items.length; n++) {
      final item = _items[n];
      if (item.status.isTerminal) continue;
      try {
        _transfers[item.id] = backend.add(item.job);
      } catch (error) {
        _items[n] = item.withStatus(DownloadStatus.failed, error: '$error');
      }
    }
    _reconcile();
    await flush();
  }

  Future<String> enqueue(TorrentDownloadJob job) async {
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    final transfer = backend.add(job);
    try {
      _items.add(transfer.snapshot(DownloadItem(id: id, job: job)));
    } catch (_) {
      transfer.remove();
      rethrow;
    }
    _transfers[id] = transfer;
    _reconcile();
    await flush();
    return id;
  }

  int _index(String id) {
    final n = _items.indexWhere((i) => i.id == id);
    if (n < 0) throw ArgumentError('Unknown download: $id');
    return n;
  }

  Future<void> pause(String id) async {
    final n = _index(id);
    if (_items[n].status.isTerminal) {
      return;
    }
    _transfers[id]!.pause();
    _items[n] = _items[n].withStatus(DownloadStatus.paused);
    _reconcile();
    await flush();
  }

  Future<void> resume(String id) async {
    final n = _index(id);
    final item = _items[n];
    if (item.status != DownloadStatus.paused &&
        item.status != DownloadStatus.failed) {
      return;
    }
    _transfers[id] ??= backend.add(item.job);
    _items[n] = item.withStatus(DownloadStatus.queued);
    _reconcile();
    await flush();
  }

  /// Cancellation preserves files by default; deletion is an explicit choice.
  Future<void> cancel(String id, {bool deleteFiles = false}) async {
    final n = _index(id);
    final item = _items[n];
    if (item.status.isTerminal) return;
    _transfers[id]?.remove(deleteFiles: deleteFiles);
    _transfers.remove(id);
    _items[n] = item.withStatus(DownloadStatus.cancelled);
    _reconcile();
    await flush();
  }

  Future<void> reorder(String id, int newIndex) async {
    final old = _index(id);
    if (newIndex < 0 || newIndex >= _items.length) {
      throw RangeError.index(newIndex, _items);
    }
    final item = _items.removeAt(old);
    _items.insert(newIndex, item);
    _reconcile();
    await flush();
  }

  Future<void> clearHistory() async {
    _items.removeWhere((i) => i.status.isTerminal);
    await flush();
  }

  Future<void> configure(DownloadSettings next) async {
    next.validate();
    backend.configure(next);
    settings = next;
    _reconcile();
    await tick();
  }

  Future<void> tick() async {
    var changed = false;
    for (var n = 0; n < _items.length; n++) {
      final previous = _items[n];
      final transfer = _transfers[previous.id];
      if (transfer == null) continue;
      try {
        var next = transfer.snapshot(previous);
        // Respect explicit pauses and never-started queued jobs.
        if (previous.status != DownloadStatus.paused &&
            (previous.status == DownloadStatus.downloading ||
                previous.seedingStartedAt != null) &&
            next.files.isNotEmpty &&
            next.files.every((f) => f.downloadedBytes >= f.totalBytes)) {
          final started = previous.seedingStartedAt ?? DateTime.now();
          final done =
              settings.seedingMode == SeedingMode.disabled ||
              (settings.seedingMode == SeedingMode.limited &&
                  next.uploadedBytes >= next.totalBytes * settings.seedRatio &&
                  DateTime.now().difference(started) >= settings.seedTime);
          next = DownloadItem(
            id: next.id,
            job: next.job,
            status: done ? DownloadStatus.completed : DownloadStatus.seeding,
            files: next.files,
            uploadedBytes: next.uploadedBytes,
            uploadBytesPerSecond: done ? 0 : next.uploadBytesPerSecond,
            peers: next.peers,
            seeds: next.seeds,
            seedingStartedAt: started,
          );
          if (done) {
            transfer.remove();
            _transfers.remove(previous.id);
          }
        }
        changed |= next.status != previous.status;
        _items[n] = next;
      } catch (error) {
        try {
          transfer.remove();
        } catch (_) {}
        _transfers.remove(previous.id);
        _items[n] = previous.withStatus(DownloadStatus.failed, error: '$error');
        changed = true;
      }
    }
    _reconcile();
    if (changed) await flush();
  }

  void _reconcile() {
    var downloads = settings.maxActiveDownloads;
    var seeds = settings.maxActiveSeeds;
    for (var n = 0; n < _items.length; n++) {
      final item = _items[n];
      if (item.status.isTerminal || item.status == DownloadStatus.paused) {
        continue;
      }
      final isSeed = item.seedingStartedAt != null;
      final allowed = isSeed ? seeds-- > 0 : downloads-- > 0;
      final status = allowed
          ? (isSeed ? DownloadStatus.seeding : DownloadStatus.downloading)
          : DownloadStatus.queued;
      if (item.status == status) continue;
      final transfer = _transfers[item.id]!;
      if (allowed) {
        transfer.resume();
      } else {
        transfer.pause();
      }
      _items[n] = item.withStatus(status);
    }
  }

  Future<void> flush() => repository.save(items);
  Future<void> dispose() async {
    try {
      for (final transfer in _transfers.values) {
        transfer.pause();
      }
      await flush();
    } finally {
      _transfers.clear();
      backend.close();
    }
  }
}
