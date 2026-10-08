import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lists/models.dart';
import '../lists/notifier.dart';
import 'models.dart';
import 'notifier.dart';

/// Series being watched or rewatched, with how far the viewer is: the ones
/// checked for new episodes, told about and downloaded automatically.
final trackedSeriesProvider = Provider<List<FollowedSeries>>((ref) {
  final watching = ref
      .watch(
        watchListsProvider.select(
          (all) => [
            for (final e in all)
              if (e.status == WatchStatus.watching ||
                  e.status == WatchStatus.rewatching)
                e.id,
          ].join(','),
        ),
      )
      .split(',')
      .toSet();
  return [
    for (final s in ref.watch(followedSeriesProvider))
      if (watching.contains(s.id)) s,
  ];
});
