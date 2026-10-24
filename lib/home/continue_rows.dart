import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../following/notifier.dart';
import '../imdb/models.dart';
import '../lists/notifier.dart';
import '../titles/pick_up.dart';
import '../watching/models.dart';
import 'watch_activity.dart';

/// Keeps known resume cards visible while individual series resolve.
class ContinueRow {
  const ContinueRow(this.title, {required this.at, this.entry, this.error});
  final ImdbTitle title;
  final DateTime at;
  final WatchEntry? entry;
  final Object? error;
}

final continueRowsProvider = Provider<List<ContinueRow>>((ref) {
  final known =
      ref.watch(continueWatchingProvider).value ?? const <WatchEntry>[];
  final rows = {
    for (final entry in known)
      entry.key: ContinueRow(
        entry.series ?? entry.title,
        at: entry.updatedAt,
        entry: entry,
      ),
  };
  final removed = ref.watch(removedListTitlesProvider);
  for (final followed in ref.watch(followedSeriesProvider)) {
    if (followed.manual ||
        removed.contains(followed.id) ||
        rows.containsKey(followed.id)) {
      continue;
    }
    final pick = ref.watch(pickUpProvider(followed.id));
    if (pick.isLoading && !pick.hasValue) {
      rows[followed.id] = ContinueRow(followed.series, at: followed.watchedAt);
    } else if (pick.hasError && !pick.hasValue) {
      rows[followed.id] = ContinueRow(
        followed.series,
        at: followed.watchedAt,
        error: pick.error,
      );
    } else if (pick.value?.item case final item?) {
      rows[followed.id] = ContinueRow(
        followed.series,
        at: followed.watchedAt,
        entry: WatchEntry.of(
          item,
          position: Duration.zero,
          duration: item.runtime ?? Duration.zero,
          at: followed.watchedAt,
        ),
      );
    }
  }
  return rows.values.toList()..sort((a, b) => b.at.compareTo(a.at));
});
