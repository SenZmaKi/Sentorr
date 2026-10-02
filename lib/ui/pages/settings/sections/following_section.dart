import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../following/models.dart';
import '../../../../following/notifier.dart';
import '../../../components/buttons.dart';
import '../../../shared/title_format.dart';
import '../settings_group.dart';

/// "Watched S2 E4 · Yesterday" or "On S2 E5 · Today".
String _reachedLine(FollowedSeries s) => [
  '${s.seen(s.reached) ? 'Watched' : 'On'} '
      '${episodeCode(s.reached.season, s.reached.episode)}',
  relativeDay(s.watchedAt),
].join(' · ');

class FollowingSection extends ConsumerWidget {
  const FollowingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followed = ref.watch(followedSeriesProvider);
    return SettingsGroup(
      title: 'Following',
      description:
          'Series you watch are followed for new episodes. Watching one '
          'again follows it again',
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
            trailing: SIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Unfollow',
              onPressed: () =>
                  ref.read(followedSeriesProvider.notifier).unfollow(s.id),
            ),
          ),
      ],
    );
  }
}
