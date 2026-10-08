import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../following/auto_downloads.dart';
import '../../../following/models.dart';
import '../../../following/notifier.dart';
import '../../../following/tracked.dart';
import '../../../lists/notifier.dart';
import '../../../settings/models.dart';
import '../../../settings/notifier.dart';
import '../../components/buttons.dart';
import '../../components/toggle.dart';
import '../../shared/theme/theme.dart';
import '../../../lists/series_standing.dart';
import '../../shared/standing_label.dart';
import '../../shared/title_format.dart';
import '../settings/settings_group.dart';

/// "Season 2 done · Yesterday", "On S2 E5 · Today" or "Added Today";
/// before [standing] is known, the furthest episode reached.
String _reachedLine(FollowedSeries s, SeriesStanding? standing) => s.manual
    ? 'Added ${relativeDay(s.watchedAt)}'
    : [
        if (standing != null)
          standingLabel(standing)
        else
          '${s.seen(s.reached) ? 'Watched' : 'On'} '
              '${episodeCode(s.reached.season, s.reached.episode)}',
        relativeDay(s.watchedAt),
      ].join(' · ');

/// Series on the Watching list, which are checked for new episodes, with
/// each one's notification and download switches.
class NewEpisodesPanel extends ConsumerWidget {
  const NewEpisodesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(trackedSeriesProvider);
    if (series.isEmpty) return const _Empty();
    final f = ref.watch(settingsProvider.select((s) => s.following));
    final notifier = ref.read(followedSeriesProvider.notifier);
    return SettingsGroup(
      title: 'Series you are watching',
      description:
          'Checked as episodes air. Turn on notifications and downloads '
          'for each; the defaults are in Settings',
      children: [
        for (final s in series)
          SettingsTile(
            icon: Icons.live_tv_outlined,
            title: s.series.title,
            subtitle: _reachedLine(
              s,
              ref.watch(seriesStandingProvider(s.id)).value,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: Space.s8,
              children: [
                SIconButton(
                  icon: s.notify
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  tooltip: s.notify
                      ? 'Stop notifying about new episodes'
                      : 'Notify about new episodes',
                  selected: s.notify,
                  onPressed: () => notifier.setNotify(s.id, !s.notify),
                ),
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
                  tooltip: 'Remove from Watching',
                  onPressed: () =>
                      ref.read(watchListsProvider.notifier).set(s.series, null),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s64),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 40,
            color: c.foregroundMuted,
          ),
          const SizedBox(height: Space.s12),
          Text(
            'No series to check',
            textAlign: TextAlign.center,
            style: context.type.subtitle.copyWith(color: c.foreground),
          ),
          const SizedBox(height: Space.s4),
          Text(
            'Series on Watching are checked for new episodes.',
            textAlign: TextAlign.center,
            style: context.type.bodySmall.copyWith(
              color: c.foregroundSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
