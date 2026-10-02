import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../following/models.dart';
import '../../../../following/notifier.dart';
import '../../../../following/auto_downloads.dart';
import '../../../../settings/models.dart';
import '../../../../settings/notifier.dart';
import '../../../components/buttons.dart';
import '../../../components/toggle.dart';
import '../../../shared/theme/theme.dart';
import '../settings_controls.dart';
import '../../../shared/title_format.dart';
import '../settings_group.dart';

/// "Watched S2 E4 · Yesterday", "On S2 E5 · Today" or "Followed Today".
String _reachedLine(FollowedSeries s) => s.manual
    ? 'Followed ${relativeDay(s.watchedAt)}'
    : [
        '${s.seen(s.reached) ? 'Watched' : 'On'} '
            '${episodeCode(s.reached.season, s.reached.episode)}',
        relativeDay(s.watchedAt),
      ].join(' · ');

class FollowingSection extends ConsumerWidget {
  const FollowingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followed = ref.watch(followedSeriesProvider);
    final f = ref.watch(settingsProvider.select((s) => s.following));
    final notifier = ref.read(followedSeriesProvider.notifier);
    void edit(FollowingSettings Function(FollowingSettings) change) => ref
        .read(settingsProvider.notifier)
        .update((a) => a.copyWith(following: change(a.following)));
    return Column(
      children: [
        SettingsGroup(
          title: 'Auto-download',
          description:
              'Episodes download as they air, so they play without waiting',
          keywords: 'automatic download new episodes offline',
          children: [
            SettingsTile(
              icon: Icons.download_for_offline_outlined,
              title: 'Download new episodes',
              subtitle: switch (f.autoDownload) {
                AutoDownload.off => 'Never on their own',
                AutoDownload.chosen =>
                  'For series you turn it on for, below or on their page',
                AutoDownload.all =>
                  'For every series you follow, unless turned off for one',
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
        ),
        SettingsGroup(
          title: 'Following',
          description:
              'Series you watch, or follow from their page, are checked for '
              'new episodes',
          keywords: 'new episodes series unfollow tracking',
          children: [
            if (followed.isEmpty)
              const SettingsTile(
                icon: Icons.live_tv_outlined,
                title: 'No series yet',
                subtitle: 'Series appear here once you watch an episode',
              ),
            for (final s in followed)
              SettingsTile(
                icon: Icons.live_tv_outlined,
                title: s.series.title,
                subtitle: _reachedLine(s),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: Space.s8,
                  children: [
                    if (f.autoDownload != AutoDownload.off)
                      Tooltip(
                        message: 'Download new episodes',
                        child: SToggle(
                          value: f.downloads(s.autoDownload),
                          semanticLabel:
                              'Download new episodes of ${s.series.title}',
                          onChanged: (v) async {
                            await notifier.setAutoDownload(s.id, v);
                            if (v) ref.read(autoDownloadsProvider).check(s.id);
                          },
                        ),
                      ),
                    SIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Unfollow',
                      onPressed: () => notifier.unfollow(s.id),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
