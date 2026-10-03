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
    return SettingsGroup(
      title: 'Following',
      description:
          'Checked for new episodes. A series joins when you watch it or '
          'press Follow on its page',
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
    );
  }
}
