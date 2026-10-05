part of 'core.dart';

extension EngineAdditions on EngineCore {
  /// Adds [source] for [owner], or adds [owner] to the torrent already
  /// holding its info hash. Returns that hash.
  Future<String> add(
    Map source, {
    required String owner,
    required String directory,
    required TorrentStorage storage,
    required List peers,
  }) async {
    lifetime.check();
    final hash = await infoHashOf(source);
    final expected = source['expectedHash'] as String?;
    if (expected != null && hash != expected.toLowerCase()) {
      throw ArgumentError('Torrent metadata hash does not match $expected');
    }
    if (source['kind'] != 'magnet') {
      final bytes = source['kind'] == 'bytes'
          ? source['value'] as Uint8List
          : await File(source['value'] as String).readAsBytes();
      source = {...source, 'private': isPrivateTorrent(bytes)};
    }
    // Reserve each hash while filesystem work yields. Two promotions must
    // not both accept different destinations before either move completes.
    final operation = (_adds[hash] ?? Future<void>.value()).then(
      (_) => _add(
        source,
        hash: hash,
        owner: owner,
        directory: directory,
        storage: storage,
        peers: peers,
      ),
    );
    final barrier = operation.then<void>((_) {}, onError: (Object _) {});
    _adds[hash] = barrier;
    try {
      return await operation;
    } finally {
      if (identical(_adds[hash], barrier)) _adds.remove(hash);
    }
  }

  Future<String> _add(
    Map source, {
    required String hash,
    required String owner,
    required String directory,
    required TorrentStorage storage,
    required List peers,
  }) async {
    lifetime.check();
    final known = _torrents[hash];
    if (known != null) {
      _checkDestination(known, directory, storage);
      if (storage.index > known.storage.index) {
        await _move(known, directory, storage);
      }
      known.lifetime.check();
      known.owners.putIfAbsent(owner, TorrentOwner.new);
      known.applyPause();
      _addTrackers(known.handle, {
        ...source,
        if (known.private) 'private': true,
      });
      _addPeers(known, peers);
      publish();
      return hash;
    }
    final root = Directory(directory);
    await root.create(recursive: true);
    final Directory save;
    final temporary = storage == TorrentStorage.temporary;
    save = temporary ? await root.createTemp('torrent-stream-') : root;
    lifetime.check();
    final session = native.session;
    final handle = switch (source['kind']) {
      'magnet' => session.addMagnet(
        magnetUri: source['value'] as String,
        savePath: save.path,
      ),
      'file' => session.addTorrentFile(
        torrentPath: source['value'] as String,
        savePath: save.path,
      ),
      'bytes' => session.addTorrentData(
        torrentData: source['value'] as Uint8List,
        savePath: save.path,
      ),
      _ => throw ArgumentError('Unsupported torrent source'),
    };
    handle.setFlags(LibtorrentTorrentFlags.defaultDontDownload);
    handle.unsetFlags(
      LibtorrentTorrentFlags.autoManaged | LibtorrentTorrentFlags.paused,
    );
    _addTrackers(handle, source);
    final entry = TorrentEntry(
      infoHash: hash,
      handle: handle,
      savePath: save.path,
      storage: storage,
      private: source['private'] == true,
    );
    if (temporary) entry.temporary.add(save);
    entry.owners[owner] = TorrentOwner();
    _torrents[hash] = entry;
    entry.applyPause();
    _addPeers(entry, peers);
    // Owners wait for metadata through [metadata]; failures surface there.
    unawaited(
      entry.prepare((ready) => waitUntil(entry.lifetime, ready)).catchError((
        Object error,
        StackTrace stack,
      ) {
        if (!entry.ready.isCompleted) entry.ready.completeError(error, stack);
      }),
    );
    unawaited(entry.ready.future.catchError((Object _) {}));
    publish();
    return hash;
  }

  void _addTrackers(TorrentHandle handle, Map source) {
    final existing = handle.getTrackers().toSet();
    final candidates = {
      ...(source['trackers'] as List? ?? const []).cast<String>(),
      if (source['private'] != true) ..._defaultTrackers,
    };
    for (final tracker in candidates.difference(existing)) {
      handle.addTracker(tracker);
    }
  }

  void _checkDestination(
    TorrentEntry entry,
    String directory,
    TorrentStorage storage,
  ) {
    if (storage == TorrentStorage.kept &&
        entry.storage == TorrentStorage.kept &&
        !p.equals(
          p.normalize(p.absolute(entry.savePath)),
          p.normalize(p.absolute(directory)),
        )) {
      throw StateError(
        'Torrent already downloads to ${entry.savePath}; '
        'cannot also download to $directory',
      );
    }
  }
}
