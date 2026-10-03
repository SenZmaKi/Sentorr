part of 'queue.dart';

/// Season commands are serialized as one operation so queued episodes cannot
/// take freed slots halfway through a batch pause. Future episodes inherit it.
extension DownloadBatches on DownloadQueue {
  bool batchCancelled(String batchId) =>
      repository.cancelledBatches.contains(batchId);

  Future<void> startBatch(String batchId) => _serial(() async {
    repository.cancelledBatches.remove(batchId);
    await _commit();
  });

  /// Cancels at once; the returned future also waits for the engine to let
  /// the torrents go, outside the command queue.
  Future<void> cancelBatch(
    String batchId, {
    Set<String> itemIds = const {},
  }) async {
    final releases = await _serial(() async {
      final releases = <Future<void>>[];
      repository.cancelledBatches.add(batchId);
      repository.pausedBatches.remove(batchId);
      for (final item in _items.toList()) {
        if ((item.job.batchId != batchId && !itemIds.contains(item.id)) ||
            item.status.isTerminal) {
          continue;
        }
        _replace(item.withStatus(DownloadStatus.cancelled));
        releases.add(_release(item));
      }
      _reconcile();
      await _commit();
      return releases;
    });
    await Future.wait(releases);
  }

  bool batchPaused(String batchId) =>
      repository.pausedBatches.contains(batchId);

  Future<void> pauseBatch(String batchId, {Set<String> itemIds = const {}}) =>
      _serial(() async {
        repository.pausedBatches.add(batchId);
        for (final item in _items.toList()) {
          if ((item.job.batchId != batchId && !itemIds.contains(item.id)) ||
              item.status.isTerminal ||
              item.status == DownloadStatus.paused) {
            continue;
          }
          if (!_attached.contains(item.id)) await _release(item);
          _replace(item.withStatus(DownloadStatus.paused));
        }
        _reconcile();
        await _commit();
      });

  Future<void> resumeBatch(String batchId, {Set<String> itemIds = const {}}) =>
      _serial(() async {
        repository.pausedBatches.remove(batchId);
        for (final item in _items.toList()) {
          if ((item.job.batchId != batchId && !itemIds.contains(item.id)) ||
              item.status != DownloadStatus.paused) {
            continue;
          }
          if (_attached.contains(item.id)) {
            _replace(item.withStatus(DownloadStatus.queued));
          } else {
            _replace(item.withStatus(DownloadStatus.preparing));
            _attach(item.id);
          }
        }
        _reconcile();
        await _commit();
      });
}
