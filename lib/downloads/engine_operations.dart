part of 'queue.dart';

/// Each preparation has its own owner: releasing a stale attempt cannot
/// remove a resumed download's hold on the same torrent.
class _DownloadAttempt {
  _DownloadAttempt(this.owner);
  final String owner;
  String? hash;
  bool deleteFiles = false;
}

extension DownloadEngineOperations on DownloadQueue {
  Future<void> _tick() async {
    final failure = torrents.failure;
    if (failure != null) {
      var changed = false;
      for (final item in _items.toList()) {
        if (item.status.isTerminal || item.status == DownloadStatus.paused) {
          continue;
        }
        await _release(item);
        _replace(item.withStatus(DownloadStatus.failed, error: failure));
        changed = true;
      }
      if (changed) {
        await _commit();
      } else {
        _publish();
      }
      return;
    }
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
  }

  void _hold(DownloadItem item, {required bool running}) {
    final hash = item.infoHash;
    final attempt = _attempts[item.id];
    if (_disposed ||
        hash == null ||
        attempt == null ||
        _running[item.id] == running) {
      return;
    }
    _running[item.id] = running;
    torrents.setPaused(hash, attempt.owner, !running).catchError((Object e) {
      if (identical(_attempts[item.id], attempt) &&
          _running[item.id] == running) {
        _running.remove(item.id);
      }
      _log.warning(
        'Could not ${running ? 'start' : 'pause'} ${_name(item)}',
        e,
      );
    });
  }

  Future<void> _release(DownloadItem item, {bool deleteFiles = false}) async {
    _attached.remove(item.id);
    _running.remove(item.id);
    final attempt = _attempts.remove(item.id);
    if (attempt == null) return;
    await _releaseAttempt(attempt, deleteFiles: deleteFiles);
  }

  Future<void> _releaseAttempt(
    _DownloadAttempt attempt, {
    bool deleteFiles = false,
  }) async {
    attempt.deleteFiles |= deleteFiles;
    final hash = attempt.hash;
    if (hash == null) return;
    try {
      await torrents
          .release(hash, attempt.owner, deleteFiles: attempt.deleteFiles)
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      _log.warning('Could not release ${attempt.owner}', error);
    }
  }
}
