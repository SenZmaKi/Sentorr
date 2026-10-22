part of 'core.dart';

extension EngineStorage on EngineCore {
  Future<void> move(String hash, String directory, TorrentStorage storage) =>
      _serialize(hash, () => _move(_entry(hash), directory, storage));

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
}
