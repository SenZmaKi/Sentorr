import '../payload.dart';
import '../../player/handoff_settings.dart';

/// Ephemeral playback presence; never merged into history or backed up.
class ContinuitySession {
  const ContinuitySession({
    required this.id,
    required this.media,
    required this.position,
    required this.duration,
    required this.playing,
    this.settings,
  });
  final String id;
  final HandoffSettings? settings;
  final PeerMedia media;
  final Duration position, duration;
  final bool playing;
  bool get buffered => media.bufferedBytes != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'media': media.toJson(),
    'position': position.inMilliseconds,
    'duration': duration.inMilliseconds,
    'playing': playing,
    if (settings != null) 'settings': settings!.toJson(),
  };

  static ContinuitySession? fromResponse(Map<String, dynamic> response) {
    if (response['version'] != 1) {
      throw const FormatException('Unsupported continuity format');
    }
    return decode(response['session']);
  }

  static ContinuitySession? decode(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid session');
    }
    final media = PeerMedia.fromJson(value['media']);
    final id = value['id'],
        position = value['position'],
        duration = value['duration'];
    if (id is! String ||
        id.isEmpty ||
        media == null ||
        position is! int ||
        position < 0 ||
        duration is! int ||
        duration <= 0 ||
        position > duration ||
        value['playing'] is! bool) {
      throw const FormatException('Invalid playback presence');
    }
    return ContinuitySession(
      id: id,
      settings: HandoffSettings.decode(value['settings']),
      media: media,
      position: Duration(milliseconds: position),
      duration: Duration(milliseconds: duration),
      playing: value['playing'] as bool,
    );
  }
}
