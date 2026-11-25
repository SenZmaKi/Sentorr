part of 'planner.dart';

extension _EnqueueDownload on DownloadPlanner {
  Future<void> _enqueue(
    PlaybackItem item,
    TorrentCandidate candidate, {
    required LibraryOrigin origin,
    String? reason,
    CancelToken? cancel,
    Uint8List? existingMetadata,
    String? directory,
    TorrentStorage storage = TorrentStorage.temporary,
    int? fileIndex,
    bool reuse = false,
  }) async {
    cancel?.throwIfCancellationRequested();
    if (cancel == null &&
        origin == LibraryOrigin.manual &&
        item.series != null &&
        item.season != null) {
      await _ref
          .read(downloadQueueProvider)
          .startBatch('${item.series!.id}:season:${item.season}');
    }
    final engine = _ref.read(torrentEngineProvider);
    final release = candidate.release;
    final planner = 'plan:${item.id}';
    _log.info('Preparing $item from ${release.name}');
    final metadata =
        existingMetadata ??
        await _ref
            .read(torrentMetadataProvider)
            .fetch(release, cancel ?? CancelToken());
    cancel?.throwIfCancellationRequested();
    final source = TorrentSource.metadata(
      metadata,
      expectedInfoHash: release.infoHash,
      trackers: release.trackers,
    );
    final String hash;
    if (reuse && storage == TorrentStorage.temporary) {
      hash = release.infoHash.toLowerCase();
      await engine.retain(hash, owner: planner);
    } else {
      hash = await engine.add(
        source,
        owner: planner,
        directory: directory ?? _ref.read(torrentDirectoryProvider),
        storage: storage,
      );
    }
    try {
      final timeout = _ref
          .read(settingsProvider)
          .streaming
          .metadataTimeoutSeconds;
      final files = await whilePlanning(
        engine.metadata(hash, timeout: Duration(seconds: timeout)),
        cancel,
      );
      cancel?.throwIfCancellationRequested();
      final file = fileIndex != null
          ? files
                .where(
                  (f) => f.index == fileIndex && !f.isPadFile && f.length > 0,
                )
                .firstOrNull
          : playableFile(
              files,
              item,
              pack: candidate.requiresFileSelection,
              seriesPack: release.isSeriesPack,
            );
      if (file == null) {
        throw DownloadPlanException(
          item.isEpisode
              ? "This torrent doesn't contain the episode."
              : "This torrent doesn't contain a playable video.",
        );
      }
      final layout = layoutFor(
        item,
        _ref.read(downloadsDirectoryProvider),
        file.path,
      );
      if (storage == TorrentStorage.cached &&
          p.equals(
            p.normalize(p.absolute(directory!)),
            p.normalize(p.absolute(layout.directory)),
          )) {
        throw const DownloadPlanException(
          'Choose a Downloads folder outside this torrent cache folder.',
        );
      }
      final id = await _ref
          .read(downloadQueueProvider)
          .enqueue(
            TorrentDownloadJob(
              title: item.label,
              batchId: item.series == null || item.season == null
                  ? null
                  : '${item.series!.id}:season:${item.season}',
              torrentData: metadata,
              trackers: release.trackers,
              destinationDirectory: layout.directory,
              selectedFileIndices: [file.index],
              renamedFiles: {file.index: layout.name},
              background: origin != LibraryOrigin.manual,
            ),
          );
      await _ref
          .read(libraryProvider.notifier)
          .add(
            LibraryEntry(
              item: item,
              downloadId: id,
              release: release,
              fileIndex: file.index,
              path: p.join(layout.directory, layout.name),
              addedAt: DateTime.now(),
              origin: origin,
              reason: reason,
            ),
          );
      _log.info('Queued $item as ${p.join(layout.directory, layout.name)}');
      // Hold the torrent until the download does, so its metadata is reused.
      final queued = _ref
          .read(downloadQueueProvider)
          .items
          .where((d) => d.id == id)
          .first;
      if (queued.status == DownloadStatus.paused) {
        if (reuse && engine.torrent(hash)?.storage != TorrentStorage.kept) {
          await engine.move(hash, layout.directory);
        }
        return;
      }
      await engine.states
          .map(
            (_) => engine
                .torrent(hash)
                ?.owners
                .any((owner) => owner.startsWith('download:$id:')),
          )
          .firstWhere((held) => held != false)
          .timeout(Duration(seconds: reuse ? 35 : 10), onTimeout: () => null);
    } finally {
      await engine.release(hash, planner);
    }
  }
}
