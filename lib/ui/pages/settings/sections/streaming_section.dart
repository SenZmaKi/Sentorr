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
              title: 'Download ahead',
              subtitle: 'Approximate minutes ahead saved to disk, or the entire file while open, even when paused',
              keywords: 'buffer prefetch stutter minutes entire file unlimited',
              trailing: LimitField(
                value: s.limitDownloadAhead ? s.downloadAheadMinutes : 0,
                presets: const {0: 'Entire file'},
                customDefault: s.downloadAheadMinutes,
                min: 1,
                unit: 'min',
                semanticLabel: 'Download ahead',
                onChanged: (n) => edit(
                  (s) => s.copyWith(
                    limitDownloadAhead: n != 0,
                    downloadAheadMinutes: n == 0 ? s.downloadAheadMinutes : n,
                  ),
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.play_circle_outline,
              title: 'Player forward buffer',
              subtitle: 'Video held in RAM ahead of playback. Applies when a file opens',
              keywords: 'memory ram cache',
              trailing: NumberField(
                value: s.playerForwardBufferMiB,
                min: 1,
                unit: 'MiB',
                semanticLabel: 'Player forward buffer in MiB',
                onSubmitted: (n) =>
                    edit((s) => s.copyWith(playerForwardBufferMiB: n)),
              ),
            ),
            SettingsTile(
              icon: Icons.replay_rounded,
              title: 'Player backward buffer',
              subtitle: 'Played packets retained by the player in RAM for quick backward seeks. Zero disables it',
              keywords: 'memory ram cache seek',
              trailing: NumberField(
                value: s.playerBackwardBufferMiB,
                unit: 'MiB',
                semanticLabel: 'Player backward buffer in MiB',
                onSubmitted: (n) =>
                    edit((s) => s.copyWith(playerBackwardBufferMiB: n)),
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
