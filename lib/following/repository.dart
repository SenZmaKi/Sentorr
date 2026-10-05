import '../shared/persistence/json_file_store.dart';
import 'models.dart';
import 'snapshot.dart';

class FollowedSeriesRepository {
  FollowedSeriesRepository(this.store);
  final JsonFileStore store;

  /// When each series was unfollowed, saved with the records so synced
  /// devices do not bring it back; filled by [load], kept by the notifier.
  Map<String, DateTime> removals = {};

  /// Most recently watched first; null before anything was ever saved.
  Future<List<FollowedSeries>?> load() async {
    final json = await store.read();
    if (json?['series'] is! List) return null;
    final snapshot = FollowedSnapshot.fromJson(json);
    removals = snapshot.removals;
    return snapshot.series;
  }

  Future<void> save(List<FollowedSeries> series) => store.write({
    'version': 1,
    ...FollowedSnapshot(series, removals).toJson(),
  });
}
