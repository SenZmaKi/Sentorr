import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../player/track_selection.dart';

/// MediaKit retains `auto` after mpv chooses a default track. Resolve its
/// actual ID without changing the native selection policy.
class AudioSelection extends StatefulWidget {
  const AudioSelection({
    super.key,
    required this.player,
    required this.tracks,
    required this.track,
    required this.builder,
    this.readNativeId,
  });

  final Player player;
  final Tracks tracks;
  final Track track;
  final Widget Function(AudioTrack?) builder;
  final Future<String?> Function()? readNativeId;

  @override
  State<AudioSelection> createState() => _AudioSelectionState();
}

class _AudioSelectionState extends State<AudioSelection> {
  String? _nativeId;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(AudioSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player ||
        oldWidget.tracks != widget.tracks ||
        oldWidget.track.audio != widget.track.audio) {
      _nativeId = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final revision = ++_revision;
    if (widget.track.audio.id != 'auto') return;
    try {
      final native = widget.player.platform;
      final selected = await resolveAudioSelection(
        widget.track.audio,
        widget.tracks.audio,
        readNativeId: () async => widget.readNativeId != null
            ? await widget.readNativeId!()
            : native is NativePlayer
            ? await native.getProperty('aid')
            : null,
      );
      if (!mounted || revision != _revision) return;
      setState(() => _nativeId = selected?.id);
    } on Object {
      // Keep the availability summary when native metadata is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final reported = widget.track.audio;
    final id = reported.id == 'auto' ? _nativeId : reported.id;
    final selected = widget.tracks.audio
        .where((t) => t.id != 'auto' && t.id != 'no' && t.id == id)
        .firstOrNull;
    return widget.builder(selected);
  }
}
