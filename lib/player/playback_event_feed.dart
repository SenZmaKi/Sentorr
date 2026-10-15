import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import 'buffering.dart';
import 'playback_events.dart';
import 'stream/stream_status.dart';

/// Feeds [events] from the player, buffering and stream status for as long
/// as the player lives. Returns a disposer.
Future<void> Function() feedPlaybackEvents(
  PlaybackEvents events,
  Player player,
  PlaybackBuffering buffering,
  ValueListenable<StreamStatus?> status,
) {
  void onBuffering() => events.buffering(buffering.value);
  StreamStatus? previous;
  void onStatus() {
    final next = status.value;
    _statusEvents(events, previous, next);
    previous = next;
  }

  buffering.addListener(onBuffering);
  status.addListener(onStatus);
  final subscriptions = <StreamSubscription<Object?>>[
    player.stream.playing.listen(events.playing),
    player.stream.position.listen(events.position),
    player.stream.rate.listen((r) => events.add('rate', {'rate': r})),
    player.stream.completed.listen((done) {
      if (done) events.add('completed');
    }),
    player.stream.track.listen(
      (t) => events.add('tracks', {
        'video': t.video.id,
        'audio': t.audio.id,
        'audioLanguage': t.audio.language,
        'subtitle': t.subtitle.id,
        'subtitleLanguage': t.subtitle.language,
      }),
    ),
    player.stream.error.listen((e) => events.add('error', {'message': e})),
    // libmpv's warnings and errors: demuxer, decoder and network trouble
    // that often never reaches the error stream.
    player.stream.log.listen(
      (line) => events.add('mpv', {
        'level': line.level,
        'prefix': line.prefix,
        'text': line.text.trim(),
      }),
    ),
  ];
  return () async {
    buffering.removeListener(onBuffering);
    status.removeListener(onStatus);
    for (final s in subscriptions) {
      await s.cancel();
    }
  };
}

void _statusEvents(
  PlaybackEvents events,
  StreamStatus? before,
  StreamStatus? after,
) {
  if (after == null) return;
  final torrent = after.torrent?.release;
  if (torrent?.infoHash != before?.torrent?.release.infoHash &&
      torrent != null) {
    events.stage('torrent', {
      'infoHash': torrent.infoHash,
      'release': torrent.name,
    });
  }
  if (after.localFile != before?.localFile && after.localFile != null) {
    events.stage('source', {'kind': 'downloaded file'});
  }
  if (after.peer != before?.peer && after.peer != null) {
    events.stage('source', {'kind': 'peer', 'peer': after.peer});
  }
  if (after.stage != before?.stage) {
    events.stage('stage', {'stage': after.stage.name});
  }
  final phase = after.transfer.phase;
  if (phase != before?.transfer.phase) {
    events.stage('phase', {'phase': phase.name});
  }
  if (after.transfer.startupStatus != before?.transfer.startupStatus &&
      after.transfer.startupStatus.startsWith('ready')) {
    events.add('torrent-startup', {'status': after.transfer.startupStatus});
  }
  if (after.problem != before?.problem && after.problem != null) {
    events.add('problem', {'message': after.problem});
  }
  if (after.transfer.failure case final f? when f != before?.transfer.failure) {
    events.add('torrent-failure', {'code': f.code.name, 'message': f.message});
  }
  if (after.next != null && after.next != before?.next) {
    events.add('switching', {
      'next': after.next!.release.name,
      'retryAt': after.retryAt?.toIso8601String(),
    });
  }
}
