import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../following/notifier.dart';
import '../titles/pick_up.dart';
import '../watching/next_episode.dart';
import '../watching/models.dart';
import '../watching/notifier.dart';

/// Paused movies/episodes and the next aired episode of started series.
/// Next metadata is persisted separately; it never counts as watched.
final continueWatchingProvider = Provider<AsyncValue<List<WatchEntry>>>((ref) {
  final entries = {for (final e in ref.watch(inProgressProvider)) e.key: e};
  for (final followed in ref.watch(followedSeriesProvider)) {
    if (followed.manual) continue;
    final entry = entries.remove(followed.id);
    final local = localPickUp(entry, followed);
    if (local?.resume == true) {
      entries[followed.id] = entry!;
      continue;
    }
    final cached =
        ref.watch(savedNextEpisodesProvider)[nextEpisodeKey(
          followed.id,
          followed.reached.season,
          followed.reached.episode,
        )];
    if (cached == null || !followed.seen(followed.reached)) continue;
    entries[followed.id] = WatchEntry.of(
      cached.item,
      position: Duration.zero,
      duration: cached.duration,
      at: followed.watchedAt,
    );
  }
  return AsyncData(
    entries.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );
});
