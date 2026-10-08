import '../following/models.dart';
import '../watching/models.dart';
import 'models.dart';

/// Lists for a viewer from before there were any: followed series are
/// being watched, and so are movies in the history unless finished.
List<ListEntry> seedLists(
  List<FollowedSeries> followed,
  List<WatchEntry> history,
) {
  final seeded = <String, ListEntry>{
    for (final s in followed)
      s.id: ListEntry(
        title: s.series,
        status: WatchStatus.watching,
        updatedAt: s.watchedAt,
      ),
  };
  for (final e in history) {
    if (e.isEpisode || seeded.containsKey(e.id)) continue;
    seeded[e.id] = ListEntry(
      title: e.title,
      status: e.progress >= FollowedSeries.caughtUpFraction
          ? WatchStatus.completed
          : WatchStatus.watching,
      updatedAt: e.updatedAt,
    );
  }
  return [...seeded.values]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}
