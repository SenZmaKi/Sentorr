part of 'torrent_playback.dart';

extension _TorrentPlaybackLifecycle on TorrentPlayback {
  /// Stops the player and releases the torrent.
  Future<void> _close() async {
    final generation = ++_generation;
    _switchTimer?.cancel();
    _item = null;
    _start = null;
    await _release();
    if (!_stale(generation)) status.value = null;
  }

  /// Stops the player and leaves a streaming torrent paused for the next
  /// play of the same item; anything else is released as [close] does.
  Future<void> _park() async {
    final session = _session, served = _served, candidate = _candidate;
    final item = _item,
        streaming = status.value?.stage == StreamStage.streaming;
    if (session == null ||
        served == null ||
        candidate == null ||
        item == null ||
        !streaming) {
      return close();
    }
    final generation = ++_generation;
    _switchTimer?.cancel();
    _item = null;
    _start = null;
    _cancel?.cancel();
    _cancel = null;
    _session = null;
    _served = null;
    _candidate = null;
    final transfer = _transfer;
    _transfer = null;
    await subtitles.reset();
    await _cleanup.run([_player.stop, if (transfer != null) transfer.cancel]);
    try {
      await session.setTransferPaused(true);
      _log.info('Parked ${candidate.release.name}');
      await parked.park(
        ParkedStream(
          itemId: item.id,
          candidate: candidate,
          session: session,
          stream: served,
        ),
      );
    } on Object catch (error) {
      _log.warning('Could not park the torrent', error);
      await _cleanup.run([session.close]);
    }
    if (!_stale(generation)) status.value = null;
  }

  /// Plays [item] from its parked session when [torrent] is none or the
  /// same release; false when nothing usable was parked.
  Future<bool> _resume(
    int generation,
    PlaybackItem item,
    TorrentCandidate? torrent,
    TorrentResolution? options,
    Duration? start,
  ) async {
    final held = parked.take(item.id);
    if (held == null) return false;
    if (torrent != null &&
        torrent.release.infoHash != held.candidate.release.infoHash) {
      unawaited(_cleanup.run([held.session.close]));
      return false;
    }
    _log.info('Resuming parked ${held.candidate.release.name}');
    status.value = StreamStatus(
      stage: StreamStage.preparing,
      torrent: held.candidate,
      options: options,
    );
    // Own the session before awaiting anything so a newer play can release it.
    _session = held.session;
    try {
      await outputReady();
      if (_stale(generation)) {
        return true;
      }
      await held.session.setTransferPaused(false);
      if (_stale(generation)) return true;
      _served = held.stream;
      _candidate = held.candidate;
      _transfer = held.session.states.listen(
        (transfer) =>
            _update(generation, (s) => s.copyWith(transfer: transfer)),
      );
      await _openStream(generation, held.stream, start);
      _update(generation, (s) => s.copyWith(stage: StreamStage.streaming));
      return true;
    } on Object catch (error) {
      if (_stale(generation)) return true;
      _log.info('Parked torrent unusable, starting afresh: $error');
      await _release();
      if (_stale(generation)) return true;
      _cancel = CancelToken();
      return false;
    }
  }

  /// Supersedes whatever was starting or playing; null if superseded in
  /// turn while the old session closed.
  Future<int?> _begin() async {
    final generation = ++_generation;
    _switchTimer?.cancel();
    await _release();
    if (_stale(generation)) return null;
    _cancel = CancelToken();
    return generation;
  }

  /// Detaches the session at once and closes it behind any earlier close,
  /// so two never shut down concurrently. Completes when all are closed.
  Future<void> _release() {
    final subtitlesReady = subtitles.reset();
    _cancel?.cancel();
    _cancel = null;
    final pending = _pendingPreparation;
    _pendingPreparation = null;
    final local = _local;
    _local = false;
    final session = _session, transfer = _transfer;
    _session = null;
    _served = null;
    _candidate = null;
    _transfer = null;
    if (local || session != null || transfer != null || pending != null) {
      return _cleanup.run([
        // Stop reads before invalidating the endpoint; still release all
        // resources if a stop or subscription cancellation fails.
        () => subtitlesReady,
        _player.stop,
        if (transfer != null) transfer.cancel,
        if (session != null) session.close,
        if (pending != null) pending.close,
      ]);
    }
    return subtitlesReady.then((_) => _cleanup.pending);
  }
}
