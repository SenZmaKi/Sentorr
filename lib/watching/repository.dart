import '../backup/watch_backup.dart';
import '../shared/persistence/json_file_store.dart';
import 'models.dart';

class WatchHistoryRepository {
  WatchHistoryRepository(this.store);
  final JsonFileStore store;

  /// When each movie or series was removed, saved with the entries so a
  /// backup can carry the removals; filled by [load], kept by the notifier.
  Map<String, DateTime> removals = {};

  /// Newest first.
  Future<List<WatchEntry>> load() async {
    final json = await store.read();
    removals = removalsFromJson(json?['removed']);
    final entries = json?['entries'];
    if (entries is! List) return [];
    return [...entries.map(WatchEntry.fromJson).nonNulls]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> save(List<WatchEntry> entries) => store.write({
    'version': 1,
    'entries': [for (final e in entries) e.toJson()],
    if (removals.isNotEmpty) 'removed': removalsToJson(removals),
  });
}
