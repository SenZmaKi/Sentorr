import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'diagnostics.dart';
import 'sample.dart';

/// Opt-in native playback check. Does not certify visual or audible correctness.
Future<bool> smokeCheck(Player player, List<Sample> samples) async {
  final results = <Map<String, dynamic>>[];
  final errors = <String>[];
  final subscription = player.stream.error.listen(errors.add);
  await player.setPlaylistMode(PlaylistMode.none);
  for (final sample in samples) {
    errors.clear();
    final result = <String, dynamic>{'title': sample.title};
    try {
      await player.open(Media(sample.uri)).timeout(const Duration(seconds: 20));
      await player.stream.position
          .firstWhere((p) => p.inMilliseconds >= 1500)
          .timeout(const Duration(seconds: 20));
      final native = player.platform as NativePlayer;
      final properties = <String, String>{};
      for (final key in Diagnostics.properties.keys) {
        properties[key] = await native.getProperty(key);
      }
      result['properties'] = properties;
      result['audioTracks'] = player.state.tracks.audio
          .map((t) => {'id': t.id, 'codec': t.codec, 'title': t.title})
          .toList();
      result['subtitleTracks'] = player.state.tracks.subtitle
          .map((t) => {'id': t.id, 'codec': t.codec, 'title': t.title})
          .toList();
      final expectedAudio = (sample.metadata['streams'] as List? ?? []).any(
        (s) => s['codec_type'] == 'audio',
      );
      result['playbackAdvanced'] = true;
      result['videoDecoded'] =
          (int.tryParse(properties['video-params/w'] ?? '') ?? 0) > 0;
      result['audioDecoderPresent'] =
          !expectedAudio ||
          (properties['audio-codec-name']?.isNotEmpty ?? false);
      await player.seek(const Duration(seconds: 4));
      await player.stream.position
          .firstWhere((p) => p.inMilliseconds >= 4500)
          .timeout(const Duration(seconds: 15));
      result['seekAdvanced'] = true;
      if (sample.uri.endsWith('tracks_subtitles.mkv')) {
        final audio = player.state.tracks.audio
            .where((t) => t.id != 'auto' && t.id != 'no')
            .toList();
        final subtitles = player.state.tracks.subtitle
            .where((t) => t.id != 'auto' && t.id != 'no')
            .toList();
        for (final track in audio) {
          await player.setAudioTrack(track);
        }
        final decodedSubtitles = <String, String>{};
        for (final track in subtitles) {
          await player.setSubtitleTrack(track);
          await player.seek(const Duration(seconds: 1));
          await player.stream.position
              .firstWhere(
                (p) => p.inMilliseconds >= 2000 && p.inMilliseconds < 4000,
              )
              .timeout(const Duration(seconds: 10));
          decodedSubtitles[track.id] = await native.getProperty('sub-text');
        }
        result['decodedSubtitleText'] = decodedSubtitles;
        result['subtitlesDecoded'] =
            decodedSubtitles.length == 2 &&
            decodedSubtitles.values.every((text) => text.trim().isNotEmpty);
        result['trackSelectionCommandsAccepted'] =
            audio.length == 2 && subtitles.length == 2;
      }
      result['passed'] =
          result['videoDecoded'] == true &&
          result['audioDecoderPresent'] == true &&
          result['trackSelectionCommandsAccepted'] != false &&
          result['subtitlesDecoded'] != false &&
          errors.isEmpty;
    } catch (error) {
      result['passed'] = false;
      result['exception'] = '$error';
    }
    result['errors'] = List<String>.of(errors);
    results.add(result);
    debugPrint('CODEC_SMOKE ${jsonEncode(result)}');
    await player.stop();
  }
  await subscription.cancel();
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'sentorr-codec-smoke.json'));
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'platform': Platform.operatingSystem,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'scope': 'Native decode, playback progression, seek and track-selection commands; no visual/audio certification',
      'results': results,
    }),
  );
  debugPrint('CODEC_SMOKE_REPORT ${file.path}');
  return results.every((result) => result['passed'] == true);
}
