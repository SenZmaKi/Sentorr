import 'dart:math';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'track_selection.dart';

import '../sync/continuity/host.dart';
import '../sync/continuity/session.dart';
import '../sync/server.dart';
import '../sync/shared_library.dart';
import 'engine.dart';
import 'handoff_settings.dart';
import '../settings/playback_preferences.dart';
import 'session.dart';
import 'stream/stream_status.dart';

/// Connects the mounted player to the peer server without giving the server
/// ownership of a player. Source generations distinguish release switches,
/// returning to an episode, and restarting playback of the same item.
void registerContinuityPlayer(Ref ref, PlaybackEngine engine) {
  final host = ref.read(continuityHostProvider);
  final nonce = Random.secure().nextInt(1 << 32).toRadixString(16);

  var handoffs = 0;
  var wasPlaying = engine.state.playing;
  final pausedFor = Stopwatch()..start();

  String getId() => '$nonce:${engine.streaming.generation}:$handoffs';
  var generation = getId();
  void track() {
    final state = engine.state;
    if (generation != getId()) {
      generation = getId();
      pausedFor.reset();
      pausedFor.start();
    }
    if (state.playing) {
      wasPlaying = true;
      pausedFor.reset();
      pausedFor.start();
    } else if (wasPlaying) {
      wasPlaying = false;
      pausedFor.reset();
      pausedFor.start();
    }
  }

  bool available() {
    final state = engine.state;
    return ref.mounted &&
        engine.streaming.item?.id ==
            ref.read(playerSessionProvider)?.current?.id &&
        engine.streaming.status.value?.stage == StreamStage.streaming &&
        engine.streaming.status.value?.peer == null &&
        !state.completed &&
        state.duration > Duration.zero &&
        (state.playing || pausedFor.elapsed < const Duration(minutes: 2));
  }

  Future<ContinuitySession?> snapshot() async {
    if (!available()) return null;
    final id = getId();
    final item = engine.streaming.item!;
    final library = await sharedLibrary(ref);
    final native = engine.player.platform;
    final reportedAudio = engine.state.track.audio;
    final audio =
        await resolveAudioSelection(
          reportedAudio,
          engine.state.tracks.audio,
          readNativeId: () async => native is NativePlayer
              ? await native
                    .getProperty('aid')
                    .timeout(const Duration(milliseconds: 500))
              : null,
        ) ??
        reportedAudio;
    if (!available() || id != getId()) return null;
    final status = engine.streaming.status.value!;
    final media = status.localFile != null
        ? library.media.where((m) => m.id == item.id).firstOrNull
        : library.streams
              .where(
                (m) =>
                    m.id == item.id &&
                    m.release.infoHash == status.torrent?.release.infoHash,
              )
              .firstOrNull;
    if (media == null) return null;
    return ContinuitySession(
      id: '$id:${media.release.infoHash}:${media.fileIndex}:${media.version ?? "buffered"}',
      media: media,
      settings: HandoffSettings(
        volume: engine.state.volume,
        speed: engine.state.rate,
        item: ItemPlaybackPreferences(
          audio: TrackPreference(audio.id, audio.title, audio.language),
          captionsEnabled: engine.streaming.subtitles.enabled,
          subtitle: switch (engine.streaming.subtitles.selected) {
            final sidecar? => TrackPreference(
              '${sidecar.file.index}',
              sidecar.label,
              null,
              file: true,
            ),
            null => switch (engine.streaming.subtitles.embeddedTrack) {
              final track? => TrackPreference(
                track.uri || track.data ? 'external' : track.id,
                track.title,
                track.language,
                file: track.uri || track.data,
              ),
              null => null,
            },
          },
        ),
      ),
      position: engine.state.position,
      duration: engine.state.duration,
      playing: engine.state.playing,
    );
  }

  host.destination.value = null;
  engine.streaming.status.addListener(track);
  ref.onDispose(() => engine.streaming.status.removeListener(track));
  final playing = engine.stream.playing.listen((playing) {
    track();
    if (playing && host.destination.value != null) {
      handoffs++;
      host.destination.value = null;
    }
  });
  ref.onDispose(playing.cancel);
  host.snapshot = snapshot;
  host.caption = (session) async {
    final current = await snapshot();
    if (current?.id != session) throw const SyncRefusal('Playback has changed');
    final captions = engine.streaming.subtitles;
    final track = captions.embeddedTrack;
    String? data;
    if (captions.selected?.path case final path?) {
      final file = File(path);
      if (await file.length() <= 512 * 1024) data = await file.readAsString();
    } else if (track?.data == true) {
      data = track!.id;
    } else if (track?.uri == true) {
      final uri = Uri.tryParse(track!.id);
      if (uri != null && (uri.scheme == 'file' || uri.scheme.isEmpty)) {
        final file = uri.scheme == 'file' ? File.fromUri(uri) : File(track.id);
        if (await file.length() <= 512 * 1024) data = await file.readAsString();
      }
    }
    if (data != null && data.length > 512 * 1024) return null;
    if ((await snapshot())?.id != session) {
      throw const SyncRefusal('Playback has changed');
    }
    return data;
  };
  host.pause = (session, authorized) async {
    final current = await snapshot();
    final generation = getId();
    if (!authorized() || current == null || current.id != session) {
      throw const SyncRefusal('Playback has changed. Try again.');
    }
    await engine.player.pause();
    // A source replacement while the native pause was pending must not
    // acknowledge a successful transfer of the old session.
    if (!ref.mounted || generation != getId()) {
      throw const SyncRefusal('Playback has changed. Try again.');
    }
    return engine.state.position;
  };
  ref.onDispose(() {
    if (host.snapshot == snapshot) {
      host.snapshot = null;
      host.pause = null;
      host.caption = null;
    }
  });
}
