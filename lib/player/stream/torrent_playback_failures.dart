part of 'torrent_playback.dart';

extension _TorrentPlaybackFailures on TorrentPlayback {
  /// Starts a pending automatic switch without waiting.
  void _switchNow() {
    final s = status.value;
    if (s?.stage == StreamStage.switching) unawaited(_switch(s!.next!));
  }

  /// Stops a pending automatic switch so the viewer can choose.
  void _hold() {
    final s = status.value;
    if (s?.stage != StreamStage.switching) return;
    _switchTimer?.cancel();
    status.value = s!.copyWith(stage: StreamStage.failed);
  }

  /// The player could not read the stream it was handed, e.g. a format it
  /// does not support: that torrent failed. False when nothing streams.
  bool _unplayable() {
    final s = status.value, item = _item;
    if (s == null ||
        item == null ||
        !(_local || _served != null) ||
        (s.stage != StreamStage.streaming &&
            s.stage != StreamStage.preparing)) {
      return false;
    }
    if (s.localFile != null) {
      _generation++;
      unawaited(_release());
      status.value = s.copyWith(
        stage: StreamStage.failed,
        problem:
            "This video couldn't be played. It may be in a format this "
            'device does not support.',
      );
      return true;
    }
    _fail(_generation, item, s.torrent, const _Unplayable(), null);
    return true;
  }

  /// Marks [candidate] failed and queues the next untried torrent, unless
  /// none is left or the automatic switches are spent.
  void _fail(
    int generation,
    PlaybackItem item,
    TorrentCandidate? candidate,
    Object error,
    StackTrace? stack,
  ) {
    if (_stale(generation) || _cancelled(error)) return;
    _log.warning('Could not stream ${item.name}', error, stack);
    final s = status.value!;
    if (s.stage == StreamStage.streaming) _start = _player.state.position;
    final failedGeneration = ++_generation;
    unawaited(_release());
    final failed = {
      ...s.failed,
      if (candidate != null) candidate.release.infoHash,
    };
    final stopped = StreamStatus(
      stage: StreamStage.failed,
      torrent: candidate ?? s.torrent,
      problem: _describe(error),
      options: s.options,
      failed: failed,
    );
    final next = candidate == null
        ? null
        : s.options?.candidates
              .where((c) => !failed.contains(c.release.infoHash))
              .firstOrNull;
    if (next == null || _autoSwitches >= TorrentPlayback.maxAutoSwitches) {
      _log.info(
        next == null
            ? 'No untried torrents left for $item'
            : 'Automatic switches spent; waiting for the viewer',
      );
      status.value = stopped;
      return;
    }
    _autoSwitches++;
    _log.info(
      'Switching to ${next.release.name} in ${TorrentPlayback.switchDelay.inSeconds}s '
      '($_autoSwitches/${TorrentPlayback.maxAutoSwitches})',
    );
    status.value = stopped.switching(
      next,
      DateTime.now().add(TorrentPlayback.switchDelay),
    );
    _switchTimer = Timer(TorrentPlayback.switchDelay, () {
      if (!_stale(failedGeneration)) unawaited(_switch(next));
    });
  }

  bool _cancelled(Object error) =>
      (error is DioException && CancelToken.isCancel(error)) ||
      (error is TorrentStreamException &&
          error.code == TorrentStreamErrorCode.cancelled);

  String _describe(Object error) => switch (error) {
    _Problem(:final message) => message,
    _Unplayable() =>
      "This video couldn't be played. It may be in a format this device "
          'does not support.',
    TorrentStreamException(code: TorrentStreamErrorCode.timeout) =>
      'No peers sent the video in time.',
    TorrentStreamException() => "The torrent couldn't be streamed.",
    _ => "Couldn't start this video. Check your connection.",
  };
}
