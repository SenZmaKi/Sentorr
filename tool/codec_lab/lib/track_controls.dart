import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class TrackControls extends StatelessWidget {
  final Player player;
  const TrackControls({super.key, required this.player});
  Future<void> _externalSubtitle(BuildContext context) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['srt', 'ass', 'ssa', 'vtt', 'sup'],
      );
      final path = file?.path;
      if (path != null) await player.setSubtitleTrack(SubtitleTrack.uri(path));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Subtitle load failed: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Tracks>(
    stream: player.stream.tracks,
    initialData: player.state.tracks,
    builder: (context, snapshot) {
      final tracks = snapshot.data!;
      return StreamBuilder<Track>(
        stream: player.stream.track,
        initialData: player.state.track,
        builder: (context, selected) => Wrap(
          spacing: 8,
          children: [
            PopupMenuButton<AudioTrack>(
              tooltip: 'Select audio track',
              onSelected: player.setAudioTrack,
              itemBuilder: (_) => [
                for (final track in tracks.audio)
                  CheckedPopupMenuItem(
                    checked: selected.data!.audio.id == track.id,
                    value: track,
                    child: Text(
                      '${track.title ?? track.id} ${track.language ?? ''} ${track.codec ?? ''}',
                    ),
                  ),
              ],
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Text('Audio tracks ▾'),
              ),
            ),
            PopupMenuButton<SubtitleTrack>(
              tooltip: 'Select subtitle track',
              onSelected: player.setSubtitleTrack,
              itemBuilder: (_) => [
                for (final track in tracks.subtitle)
                  CheckedPopupMenuItem(
                    checked: selected.data!.subtitle.id == track.id,
                    value: track,
                    child: Text(
                      '${track.title ?? track.id} ${track.language ?? ''}',
                    ),
                  ),
              ],
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Text('Subtitle tracks ▾'),
              ),
            ),
            TextButton(
              onPressed: () => _externalSubtitle(context),
              child: const Text('Load subtitle file'),
            ),
          ],
        ),
      );
    },
  );
}
