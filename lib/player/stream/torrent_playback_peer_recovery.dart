part of 'torrent_playback.dart';

extension _TorrentPlaybackPeerRecovery on TorrentPlayback {
  void _watchPeer() {
    _peerPositions = _player.stream.position.listen((position) {
      if (status.value?.stage == StreamStage.streaming &&
          position > Duration.zero) {
        final target = _peerSeekTarget;
        if (target != null &&
            (position - target).abs() > const Duration(seconds: 2)) {
          return;
        }
        _peerSeekTarget = null;
        _lastPosition = position;
      }
    });
    _peerErrors = _player.stream.error.listen((_) {
      if (_peerFile != null) _peerHadError = true;
    });
    _peerPlaying = _player.stream.playing.listen((playing) {
      if (_peerRecovery == null && !_peerHadError) {
        _peerDesiredPlaying = playing;
      }
    });
    _peerWatchdog = PeerStallWatchdog(
      grace: peerStallGrace,
      sample: () =>
          _peerFile == null ||
              _pinnedSource ||
              _peerRecovery != null ||
              status.value?.stage != StreamStage.streaming
          ? null
          : (
              source: _peerFile!,
              position: _player.state.position,
              playing: _player.state.playing,
              completed: _player.state.completed,
            ),
      recover: () => unawaited(_recoverPeer()),
    );
  }

  void _restorePeerCaptions(PeerFile? source) {
    if (source?.captionData case final data?) {
      subtitles.restoreExternal(
        data,
        title: source?.captionTitle,
        enabled: source?.captionsEnabled ?? false,
      );
    }
  }

  Future<void> _recoverPeer() async {
    final original = _peerFile, currentItem = _item;
    if (original == null || currentItem == null || _peerRecovery != null) {
      return;
    }
    final caption = subtitles.embeddedTrack;
    final peer = original.withCaption(
      data: caption?.data == true ? caption!.id : null,
      title: caption?.title,
      enabled: subtitles.enabled,
    );
    _peerFile = peer;
    if (_pinnedSource) {
      _fail(_generation, currentItem, null, const _Unplayable(), null);
      return;
    }
    final owner = Object();
    _peerRecovery = owner;
    final resume = resumePosition;
    final desired = _peerDesiredPlaying;
    var generation = await _begin();
    if (generation == null || !identical(_peerRecovery, owner)) return;
    bool current() => identical(_peerRecovery, owner) && !_stale(generation!);
    void waiting(String label) {
      if (current()) {
        status.value = StreamStatus(
          stage: StreamStage.reconnecting,
          peer: peer.deviceName,
          problem: label,
        );
      }
    }

    waiting('Reconnecting to ${peer.deviceName}');
    try {
      final recovered =
          peer.available != null &&
          await peerRecoveryPolicy.run(
            current: current,
            attempt: (timeout) async {
              final attemptGeneration = generation!;
              final reachable = await peer.available!();
              if (!current() || _stale(attemptGeneration)) return false;
              if (!reachable) return false;
              waiting('Waiting for video from ${peer.deviceName}');
              await _playLocal(
                attemptGeneration,
                currentItem,
                peer.url,
                resume,
                peer: peer.deviceName,
                buffered: peer.buffered,
                autoplay: () => desired && canAutoplay(),
              );
              final loaded = status.value!;
              waiting('Waiting for video from ${peer.deviceName}');
              final clock = Stopwatch()..start();
              while (current() &&
                  !_stale(attemptGeneration) &&
                  clock.elapsed < timeout) {
                final state = _player.state;
                if ((!(desired && canAutoplay()) &&
                        state.duration > Duration.zero) ||
                    state.position > resume) {
                  status.value = loaded.copyWith(stage: StreamStage.streaming);
                  _lastPosition = state.position;
                  _peerHadError = false;
                  return true;
                }
                await Future<void>.delayed(const Duration(milliseconds: 50));
              }
              return false;
            },
            wait: (delay) async {
              if (!current()) return;
              generation = await _begin();
              if (generation == null || !identical(_peerRecovery, owner)) {
                return;
              }
              waiting('Reconnecting to ${peer.deviceName}');
              await Future.any([
                Future<void>.delayed(delay),
                _cancel!.whenCancel.then<void>((_) {}),
              ]);
            },
          );
      if (!current() || recovered) return;
      // Keep the saved position before stopping/replacing the failed player.
      _lastPosition = _start = resume;
      _failedPeers.add(peer.url);
      for (
        var candidate = 0;
        candidate < 3 && peerLookup != null;
        candidate++
      ) {
        PeerFile? replacement;
        try {
          replacement = await peerLookup!(
            currentItem,
            _failedPeers,
          ).timeout(const Duration(seconds: 3));
        } on Object {
          break;
        }
        if (!current()) return;
        if (replacement == null || _failedPeers.contains(replacement.url)) {
          break;
        }
        _failedPeers.add(replacement.url);
        _peerFile = replacement.withCaption(
          data: peer.captionData,
          title: peer.captionTitle,
          enabled: peer.captionsEnabled,
        );
        generation = await _begin();
        if (generation == null || !identical(_peerRecovery, owner)) return;
        try {
          await _playLocal(
            generation!,
            currentItem,
            replacement.url,
            resume,
            peer: replacement.deviceName,
            buffered: replacement.buffered,
            autoplay: () => desired && canAutoplay(),
          ).timeout(const Duration(seconds: 4));
          _peerHadError = false;
          _peerDesiredPlaying = desired;
          return;
        } on Object {
          if (!current()) return;
        }
      }
      generation = await _begin();
      if (generation == null || !identical(_peerRecovery, owner)) return;
      _peerFile = null;
      _fallbackOrigin = peer;
      status.value = const StreamStatus(
        stage: StreamStage.connecting,
        problem: 'Device unavailable. Continuing on this device',
      );
      final local = offline(currentItem);
      if (local is LocalFile && File(local.path).existsSync()) {
        await _playLocal(
          generation!,
          currentItem,
          Uri.file(local.path),
          resume,
          transfers: local.transfers,
          autoplay: () => desired && canAutoplay(),
        );
        _restorePeerCaptions(peer);
      } else {
        final candidate = local is DownloadTorrent
            ? local.torrent
            : peer.torrent;
        final selected = candidate ?? (await find(currentItem, _cancel!)).best;
        if (!current()) return;
        if (selected == null) {
          throw const _Problem('No torrent available for recovery');
        }
        await _stream(
          generation!,
          currentItem,
          selected,
          resume: resume,
          fileIndex: local is DownloadTorrent
              ? local.fileIndex
              : peer.fileIndex,
        );
      }
    } catch (error, stack) {
      if (current()) _fail(generation!, currentItem, null, error, stack);
    } finally {
      if (identical(_peerRecovery, owner)) {
        _peerRecovery = null;
        _peerWatchdog.reset();
      }
    }
  }
}
