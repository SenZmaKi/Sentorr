import 'dart:async';

import 'package:media_kit/media_kit.dart';

import '../track_labels.dart';
import '../../settings/playback_preferences.dart';

/// Applies a language default once tracks arrive. Manual choices own the
/// current file; numeric track IDs are never carried into the next file.
class PlaybackAudio {
  PlaybackAudio(
    this.player, {
    required this.preferredLanguage,
    this.saved,
    this.onChoose,
  }) {
    _tracks = player.stream.tracks.listen((_) => _applyDefault());
  }

  final Player player;
  final TrackPreference? Function()? saved;
  final void Function(TrackPreference)? onChoose;
  final String Function() preferredLanguage;
  late final StreamSubscription<Tracks> _tracks;
  bool _opened = false, _explicit = false;
  int _generation = 0;
  String? _applied;
  Future<void> _commands = Future.value();

  void opened() {
    _opened = true;
    _applyDefault();
  }

  Future<void> reset() {
    _generation++;
    _opened = _explicit = false;
    _applied = null;
    // Restore native default selection before opening another file.
    _select(AudioTrack.auto());
    return _commands;
  }

  void choose(AudioTrack track) {
    _explicit = true;
    onChoose?.call(TrackPreference(track.id, track.title, track.language));
    _select(track);
  }

  void _applyDefault() {
    if (!_opened || _explicit) return;
    final preference = saved?.call();
    final restored = player.state.tracks.audio
        .where(
          (t) =>
              t.id != 'auto' &&
              t.id != 'no' &&
              preference?.matches(t.id, t.title, t.language) == true,
        )
        .firstOrNull;
    if (restored != null) {
      if (restored.id != _applied) _select(restored);
      return;
    }
    final language = trackLanguage(preferredLanguage(), null);
    if (language == null) return;
    final match = player.state.tracks.audio
        .where(
          (t) =>
              t.id != 'auto' &&
              t.id != 'no' &&
              trackLanguage(t.title, t.language) == language,
        )
        .firstOrNull;
    if (match != null && match.id != _applied) _select(match);
  }

  void _select(AudioTrack track) {
    _applied = track.id;
    final generation = _generation;
    _commands = _commands.then((_) async {
      if (generation != _generation || _applied != track.id) return;
      try {
        await player.setAudioTrack(track);
      } on Object {
        if (generation == _generation && _applied == track.id) {
          _applied = null;
        }
      }
    });
  }

  void dispose() {
    _generation++;
    unawaited(_tracks.cancel());
  }
}
