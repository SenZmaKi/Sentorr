import '../shared/persistence/json_file_store.dart';
import 'models.dart';

class FollowedSeriesRepository {
  FollowedSeriesRepository(this.store);
  final JsonFileStore store;

  /// Most recently watched first; null before anything was ever saved.
  Future<List<FollowedSeries>?> load() async {
    final json = await store.read();
    final series = json?['series'];
    if (series is! List) return null;
    return [...series.map(FollowedSeries.fromJson).nonNulls]
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
  }

  Future<void> save(List<FollowedSeries> series) => store.write({
    'version': 1,
    'series': [for (final s in series) s.toJson()],
  });
}
