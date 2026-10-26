import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../imdb/models.dart';
import '../settings/notifier.dart';
import '../sync/continuity/session.dart';
import 'engine.dart';
import 'session.dart';
import 'stream/offline_source.dart';
import 'stream/stream_status.dart';
import 'queue_builder.dart';

/// Opens the requested source paused, and waits for the native demuxer to
/// recognise it. No source pause is requested on a failed or cancelled open.
class ContinuityPlayback {
  ContinuityPlayback(this.ref);
  final Ref ref;
  Object? _request;
  PlaybackEngine? _engine;
  String? _itemId;
  int? _generation;

  bool get current =>
      ref.mounted &&
      identical(ref.read(playerSessionProvider)?.request, _request) &&
      ref.read(playerSessionProvider)?.current?.id == _itemId &&
      (_generation == null || _engine?.streaming.generation == _generation);

  Future<void> prepare(ContinuitySession session, PeerFile source) async {
    if (ref.read(playerSessionProvider) != null) {
      throw StateError('Close the current player before continuing here.');
    }
    final item = session.media.item;
    _itemId = item.id;
    final request = item.series == null
        ? PlayTitle(item.title)
        : PlayEpisode(
            item.series!,
            ImdbEpisode(
              title: item.title,
              seasonNumber: item.season,
              episodeNumber: item.episode,
            ),
            season: item.season,
          );
    final settings = session.settings;
    if (settings != null) {
      await ref
          .read(settingsProvider.notifier)
          .update(
            (s) => s.copyWith(
              streaming: s.streaming.copyWith(
                playback: settings.applyTo(s.streaming.playback, item.id),
              ),
            ),
          );
      if (!ref.mounted || ref.read(playerSessionProvider) != null) {
        throw StateError('Handoff cancelled');
      }
    }
    _request = request;
    ref
        .read(playerSessionProvider.notifier)
        .play(
          request,
          source: source,
          start: session.position,
          autoplay: false,
        );
    final engine = ref.read(playbackEngineProvider);
    _engine = engine;
    if (settings != null) {
      await engine.player.setVolume(settings.volume);
      await engine.player.setRate(settings.speed);
    }
    final clock = Stopwatch()..start();
    while (current && clock.elapsed < const Duration(seconds: 30)) {
      final stage = engine.streaming.status.value?.stage;
      if (stage == StreamStage.failed || stage == StreamStage.switching) {
        throw StateError(
          'Could not prepare the stream. Playback stays on the other device.',
        );
      }
      if (stage == StreamStage.streaming &&
          engine.state.duration > Duration.zero &&
          (engine.state.width ?? 0) > 0 &&
          engine.streaming.status.value?.peer == source.deviceName) {
        _generation = engine.streaming.generation;
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    throw StateError(
      current ? 'The stream took too long to prepare.' : 'Handoff cancelled',
    );
  }

  Future<void> start(Duration position) async {
    if (!current) throw StateError('Handoff cancelled');
    await _engine!.seek(position);
    if (!current) throw StateError('Handoff cancelled');
    _engine!.streaming.allowPeerRecovery();
    await _engine!.player.play();
    if (current) ref.read(playerSessionProvider.notifier).enableAutoplay();
  }

  void close() {
    if (current) ref.read(playerSessionProvider.notifier).close();
  }
}
