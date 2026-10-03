import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../settings/models.dart';
import '../../../../settings/notifier.dart';
import '../../../components/toggle.dart';
import '../settings_controls.dart';
import '../settings_group.dart';
import 'torrent_files_group.dart';

class StreamingSection extends ConsumerWidget {
  const StreamingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider.select((s) => s.streaming));
    final notifier = ref.read(settingsProvider.notifier);
    void edit(StreamingSettings Function(StreamingSettings) change) =>
        notifier.update((a) => a.copyWith(streaming: change(a.streaming)));
    int mb(int bytes) => (bytes / megabyte).round();
    return Column(
      children: [
        SettingsGroup(
          title: 'Playback',
          children: [
            SettingsTile(
              icon: Icons.pause_circle_outline_rounded,
              title: 'Pause when leaving the app',
              subtitle:
                  'Resumes when you return. Pop-out playback keeps playing',
              keywords: 'focus background alt tab resume',
              trailing: SToggle(
                value: s.pauseOnFocusLoss,
                semanticLabel: 'Pause when leaving the app',
                onChanged: (v) => edit((s) => s.copyWith(pauseOnFocusLoss: v)),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: 'Buffering',
          description:
              'How far streams stay ahead of the video, and how long '
              'a slow torrent gets',
          children: [
            SettingsTile(
              icon: Icons.fast_forward_outlined,
              title: 'Read ahead',
              subtitle:
                  'Fetched ahead of what is playing; more rides out '
                  'slow peers but takes longer to start',
              keywords: 'buffer prefetch stutter',
              trailing: NumberField(
                value: mb(s.readAheadBytes),
                min: 1,
                max: 1024,
                unit: 'MB',
                semanticLabel: 'Read ahead in megabytes',
                onSubmitted: (n) =>
                    edit((s) => s.copyWith(readAheadBytes: n * megabyte)),
              ),
            ),
            SettingsTile(
              icon: Icons.memory_rounded,
              title: 'Memory cache',
              subtitle:
                  'Recently played pieces kept in memory, so seeking '
                  'back is instant',
              keywords: 'piece cache ram seek',
              trailing: LimitField(
                value: mb(s.pieceCacheBytes),
                presets: const {0: 'Off'},
                customDefault: 24,
                min: 1,
                max: 1024,
                unit: 'MB',
                semanticLabel: 'Memory cache',
                onChanged: (n) =>
                    edit((s) => s.copyWith(pieceCacheBytes: n * megabyte)),
              ),
            ),
            SettingsTile(
              icon: Icons.hourglass_empty_rounded,
              title: 'Connection timeout',
              subtitle:
                  'How long to wait for a torrent\'s file list '
                  'before giving up',
              keywords: 'metadata magnet peers',
              trailing: NumberField(
                value: s.metadataTimeoutSeconds,
                min: 5,
                max: 600,
                unit: 's',
                semanticLabel: 'Connection timeout in seconds',
                onSubmitted: (n) =>
                    edit((s) => s.copyWith(metadataTimeoutSeconds: n)),
              ),
            ),
            SettingsTile(
              icon: Icons.timer_off_outlined,
              title: 'Stall timeout',
              subtitle:
                  'How long playback waits on a piece before the '
                  'torrent counts as failed',
              keywords: 'piece buffering stuck frozen',
              trailing: NumberField(
                value: s.pieceTimeoutSeconds,
                min: 5,
                max: 600,
                unit: 's',
                semanticLabel: 'Stall timeout in seconds',
                onSubmitted: (n) =>
                    edit((s) => s.copyWith(pieceTimeoutSeconds: n)),
              ),
            ),
          ],
        ),
        TorrentFilesGroup(settings: s, edit: edit),
      ],
    );
  }
}
