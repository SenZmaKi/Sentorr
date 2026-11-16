part of 'core.dart';

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
          await entry.lifetime.wait(
            done.future.timeout(const Duration(minutes: 10)),
          );
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
}
