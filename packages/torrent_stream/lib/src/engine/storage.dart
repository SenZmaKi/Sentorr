part of 'core.dart';

extension EngineStorage on EngineCore {
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
    }
    await entry.disk.exclusive(() async {
      for (final MapEntry(key: index, value: name) in names.entries) {
        final outcome = Completer<AlertInfo>();
        final subscription = native.events.listen((alert) {
          if (!outcome.isCompleted &&
              alert.torrentId == entry.handle.id &&
              (alert.type == 7 || alert.type == 8)) {
            outcome.complete(alert);
          }
        });
        try {
          entry.handle.renameFile(index, name);
          final alert = await entry.lifetime.wait(
            outcome.future.timeout(const Duration(seconds: 30)),
          );
          if (alert.type == 8) throw StateError(alert.message);
          entry.refreshFiles();
        } finally {
          await subscription.cancel();
        }
      }
    });
    publish();
  }

  /// Moves the torrent's files to [directory], kept as [storage].
  Future<void> move(String hash, String directory, TorrentStorage storage) =>
      _serialize(hash, () {
        final entry = _entry(hash);
        return entry.disk.exclusive(() => _move(entry, directory, storage));
      });

  Future<T> _serialize<T>(String hash, Future<T> Function() run) async {
    final operation = (_adds[hash] ?? Future<void>.value()).then((_) => run());
    final barrier = operation.then<void>((_) {}, onError: (Object _) {});
    _adds[hash] = barrier;
    try {
      return await operation;
    } finally {
      if (identical(_adds[hash], barrier)) _adds.remove(hash);
    }
  }

  Future<void> _move(
    TorrentEntry entry,
    String directory,
    TorrentStorage storage,
  ) async {
    if (storage == TorrentStorage.temporary) {
      throw ArgumentError('Torrents move only into caller folders');
    }
    await Directory(directory).create(recursive: true);
    if (entry.savePath != directory) {
      final outcome = Completer<AlertInfo>();
      final subscription = native.events.listen(
        (alert) {
          if (!outcome.isCompleted &&
              alert.torrentId == entry.handle.id &&
              (alert.type == 33 || alert.type == 34)) {
            outcome.complete(alert);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!outcome.isCompleted) outcome.completeError(error, stack);
        },
      );
      try {
        entry.handle.moveStorage(directory);
        final alert = await outcome.future.timeout(const Duration(seconds: 30));
        if (alert.type == 34) throw StateError(alert.message);
      } finally {
        await subscription.cancel();
      }
      entry.lifetime.check();
    }
    entry.savePath = directory;
    entry.storage = storage;
    final left = [...entry.temporary];
    entry.temporary.clear();
    for (final folder in left) {
      unawaited(deleteWhenEmptied(folder));
    }
    publish();
  }
}
