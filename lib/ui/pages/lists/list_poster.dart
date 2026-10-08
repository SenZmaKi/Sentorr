import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../lists/models.dart';
import '../../../lists/series_standing.dart';
import '../../components/cards/card_parts.dart';
import '../../components/cards/title_poster.dart';
import '../../shared/play_route.dart';
import '../../shared/standing_label.dart';
import '../../shared/title_route.dart';

/// A poster on a list, its line under the title saying where the viewer
/// is: how far into a series, or how often a completed title was
/// rewatched. Otherwise the usual facts.
class ListPoster extends ConsumerWidget {
  const ListPoster({super.key, required this.entry});

  final ListEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = entry.title;
    final standing = t.canHaveEpisodes == true
        ? ref.watch(seriesStandingProvider(t.id)).value
        : null;
    return titlePoster(
      t,
      meta: [
        if (standing != null)
          MetaItem(standingLabel(standing), icon: Icons.live_tv_outlined),
        if (entry.rewatches > 0)
          MetaItem('Rewatched ${entry.rewatches}×', icon: Icons.replay_rounded),
        if (standing == null && entry.rewatches == 0) ...titleFacts(t),
      ],
      onOpen: () => ref.openTitle(t),
      onPlay: () => ref.playOrPickUp(t),
    );
  }
}
