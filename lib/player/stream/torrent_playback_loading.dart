part of 'torrent_playback.dart';

extension _TorrentPlaybackLoading on TorrentPlayback {
  /// Plays the downloaded file at [path]; no torrent is involved.
  /// Plays a finished download from [uri]: a file here, or a paired
  /// device's through the loopback proxy.
  Future<void> _playLocal(
    int generation,
    PlaybackItem item,
    Uri uri,
    Duration? start, {
    String? peer,
  }) async {
    _log.info('Playing $item from ${peer ?? uri.toFilePath()}');
    status.value = StreamStatus(
      stage: StreamStage.preparing,
      localFile: peer == null ? uri.toFilePath() : uri.toString(),
      peer: peer,
    );
    await outputReady();
    if (_stale(generation)) return;
    _local = true;
    _openingGeneration = generation;
    try {
      await _player.open(Media(uri.toString(), start: start));
    } finally {
      if (_openingGeneration == generation) _openingGeneration = null;
    }
    _update(generation, (s) => s.copyWith(stage: StreamStage.streaming));
  }

  /// Streams [candidate], choosing [fileIndex] when the download knows it.
  Future<void> _stream(
    int generation,
    PlaybackItem item,
    TorrentCandidate candidate, {
    Duration? resume,
    int? fileIndex,
  }) async {
    _update(
      generation,
      (s) => s.copyWith(stage: StreamStage.connecting, torrent: candidate),
    );
    final clock = Stopwatch()..start();
    await outputReady();
    if (_stale(generation)) return;
    final config = await configFor(candidate.release);
    if (_stale(generation)) return;
    final session = _session = TorrentStreamSession(
      engine: engine,
      config: config,
    );
    _transfer = session.states.listen(
      (transfer) => _update(generation, (s) => s.copyWith(transfer: transfer)),
    );
    final release = candidate.release;
    _log.info(
      'Streaming $item from ${release.name} '
      '(${release.infoHash}, ${release.seeders} seeders)',
    );
    final files = await session.open(TorrentSource.magnet(release.magnet));
    if (_stale(generation)) return;
    _log.info(
      'Metadata: ${files.length} files in ${clock.elapsedMilliseconds}ms',
    );
    final file =
        files.where((f) => f.index == fileIndex).firstOrNull ??
        playableFile(
          files,
          item,
          pack: candidate.requiresFileSelection,
          seriesPack: release.isSeriesPack,
        );
    if (file == null) {
      _log.info(
        'No playable file among: '
        '${files.map((f) => f.path).take(20).join(', ')}',
      );
      throw _Problem(
        item.isEpisode
            ? "This torrent doesn't contain the episode."
            : "This torrent doesn't contain a playable video.",
      );
    }
    _log.info('Chose ${file.path} (${_mib(file.length)})');
    _update(generation, (s) => s.copyWith(stage: StreamStage.preparing));
    final stream = await session.prepareFile(file.index);
    if (_stale(generation)) return;
    _served = stream;
    _candidate = candidate;
    await _openStream(generation, stream, resume);
    _update(generation, (s) => s.copyWith(stage: StreamStage.streaming));
    _log.info('Playing $item after ${clock.elapsedMilliseconds}ms');
  }

  Future<void> _openStream(
    int generation,
    TorrentStream stream,
    Duration? start,
  ) async {
    _openingGeneration = generation;
    try {
      await _adapter.open(
        stream,
        start: start,
        isCurrent: () => !_stale(generation),
      );
    } finally {
      if (_openingGeneration == generation) _openingGeneration = null;
    }
  }
}
