part of 'core.dart';

/// How long a flush or piece check may go without progress. Large files on
/// slow disks take as long as they take; only a check that stops moving fails.
const _stall = Duration(minutes: 5);

extension EngineVerification on EngineCore {
  Future<List<int>> verify(String hash) async {
    final entry = _entry(hash);
    await entry.lifetime.wait(entry.ready.future);
    return entry.disk.exclusive(() async {
      Future<void> operation(int type, void Function() start) async {
        final done = Completer<void>();
        final subscription = native.events.listen((alert) {
          if (alert.torrentId == entry.handle.id &&
              alert.type == type &&
              !done.isCompleted) {
            done.complete();
          }
        });
        try {
          start();
          await entry.lifetime.wait(_unlessStalled(done.future));
        } finally {
          await subscription.cancel();
        }
      }

      // Subscribe before issuing commands: small torrents can check immediately.
      await operation(58, entry.handle.flushCache);
      await operation(41, entry.handle.forceRecheck);
      final snapshot = entry.snapshot();
      publish();
      return snapshot.fileBytes;
    });
  }

  /// Waits for [done] while any torrent in the session advances its check:
  /// libtorrent hashes one at a time, so a queued check moves only once
  /// those ahead of it finish.
  Future<void> _unlessStalled(Future<void> done) async {
    double checked() {
      var total = 0.0;
      for (final handle in native.session.getTorrents()) {
        try {
          final status = handle.getStatus();
          if (status.state == 1) total += status.progress;
        } catch (_) {
          // A handle being removed has nothing left to check.
        }
      }
      return total;
    }

    final stalled = Completer<void>();
    var last = checked();
    var moved = DateTime.now();
    final timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = checked();
      if (now != last) {
        last = now;
        moved = DateTime.now();
      } else if (DateTime.now().difference(moved) > _stall &&
          !stalled.isCompleted) {
        stalled.completeError(TimeoutException('Piece check stalled', _stall));
      }
    });
    try {
      await Future.any([done, stalled.future]);
    } finally {
      timer.cancel();
    }
  }
}
