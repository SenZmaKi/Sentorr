import 'package:media_kit/media_kit.dart';

/// MediaKit can retain `auto` after mpv chooses a concrete track. Use its
/// actual selection when displaying or transferring playback intent.
Future<AudioTrack?> resolveAudioSelection(
  AudioTrack reported,
  List<AudioTrack> tracks, {
  required Future<String?> Function() readNativeId,
}) async {
  var id = reported.id;
  if (id == 'auto') {
    try {
      id = await readNativeId() ?? id;
    } on Object {
      return null;
    }
  }
  if (id == 'no') return AudioTrack.no();
  return tracks.where((t) => t.id != 'auto' && t.id == id).firstOrNull;
}
