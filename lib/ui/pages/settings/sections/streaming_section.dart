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
          title: 'Network',
          description: 'Applies to the next torrent that starts',
          children: [
            SettingsTile(
              icon: Icons.speed_rounded,
              title: 'Download limit',
              subtitle: 'Per torrent',
              keywords: 'speed bandwidth',
              trailing: LimitField(
                value: mb(s.downloadLimitBytesPerSecond),
                presets: const {0: 'Unlimited'},
                customDefault: 10,
                min: 1,
                unit: 'MB/s',
                semanticLabel: 'Download limit',
                onChanged: (n) => edit(
                  (s) => s.copyWith(downloadLimitBytesPerSecond: n * megabyte),
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.hub_outlined,
              title: 'Connect over uTP',
              subtitle: 'Reach more peers, including those behind routers',
              keywords: 'transport utp tcp peers',
              trailing: SToggle(
                value: s.utp,
                semanticLabel: 'Connect over uTP',
                onChanged: (v) => edit((s) => s.copyWith(utp: v)),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: 'Buffering',
          description: 'How the engine keeps ahead of the video',
          children: [
            SettingsTile(
              icon: Icons.fast_forward_outlined,
              title: 'Read ahead',
              subtitle: 'Downloaded ahead of what is playing',
              keywords: 'buffer prefetch',
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
              subtitle: 'Recently read pieces kept in memory',
              keywords: 'piece cache ram',
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
              subtitle: 'How long to wait for a torrent\'s file list',
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
              subtitle: 'How long a piece may take before the torrent fails',
              keywords: 'piece buffering stuck',
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
