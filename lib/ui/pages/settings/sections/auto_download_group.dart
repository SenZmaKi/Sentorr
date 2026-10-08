import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../following/auto_downloads.dart';
import '../../../../settings/models.dart';
import '../../../../settings/notifier.dart';
import '../settings_controls.dart';
import '../settings_group.dart';

/// Whether followed series download new episodes on their own, and how
/// many each keeps.
class AutoDownloadGroup extends ConsumerWidget {
  const AutoDownloadGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(settingsProvider.select((s) => s.following));
    void edit(FollowingSettings Function(FollowingSettings) change) => ref
        .read(settingsProvider.notifier)
        .update((a) => a.copyWith(following: change(a.following)));
    return SettingsGroup(
      title: 'Auto-download',
      description:
          'New episodes of series you are watching download as they air, ready '
          'to watch offline',
      keywords: 'automatic new episodes offline watching following',
      children: [
        SettingsTile(
          icon: Icons.download_for_offline_outlined,
          title: 'Download new episodes',
          subtitle: switch (f.autoDownload) {
            AutoDownload.off => 'Never on their own',
            AutoDownload.chosen =>
              'For series you turn it on for, here or from their list '
                  'button',
            AutoDownload.all =>
              'For every series you are watching, unless turned off for one',
          },
          keywords: 'auto download default',
          trailing: ChoiceField<AutoDownload>(
            value: f.autoDownload,
            options: AutoDownload.values,
            labelOf: (m) => switch (m) {
              AutoDownload.off => 'Off',
              AutoDownload.chosen => 'Series I choose',
              AutoDownload.all => 'Every series',
            },
            semanticLabel: 'Download new episodes',
            onChanged: (m) {
              edit((f) => f.copyWith(autoDownload: m));
              if (m != AutoDownload.off) {
                ref.read(autoDownloadsProvider).checkAll();
              }
            },
          ),
        ),
        SettingsTile(
          icon: Icons.layers_outlined,
          title: 'Episodes kept per series',
          subtitle: f.keepEpisodes == 0
              ? 'Every downloaded episode stays until you delete it'
              : 'Older automatic downloads are deleted',
          keywords: 'keep retention delete old episodes space',
          enabled: f.autoDownload != AutoDownload.off,
          trailing: LimitField(
            value: f.keepEpisodes,
            presets: const {0: 'All'},
            customDefault: 5,
            min: 1,
            max: FollowingSettings.maxKeptEpisodes,
            unit: 'episodes',
            semanticLabel: 'Episodes kept per series',
            onChanged: (n) => edit((f) => f.copyWith(keepEpisodes: n)),
          ),
        ),
      ],
    );
  }
}
