import '../backup/watch_backup.dart';
import '../shared/persistence/json_file_store.dart';
import 'models.dart';
import '../shared/state_clock.dart';

class WatchHistoryRepository {
  WatchHistoryRepository(this.store);
  final JsonFileStore store;
  int clock = 0;

  /// When each movie or series was removed, saved with the entries so a
  /// backup can carry the removals; filled by [load], kept by the notifier.
  Map<String, DateTime> removals = {};
  Map<String, int> removalRevisions = {};

  /// Newest first.
  Future<List<WatchEntry>> load() async {
    final json = await store.read();
    clock = json?['clock'] is int ? json!['clock'] as int : 0;
    removals = removalsFromJson(json?['removed']);
    removalRevisions = removalRevisionsFromJson(json?['removed']);
    final entries = json?['entries'];
    if (entries is! List) return [];
    return [...entries.map(WatchEntry.fromJson).nonNulls]
      ..sort((a, b) => compareWatch(b, a));
  }

  Future<void> save(List<WatchEntry> entries) => store.write({
    'version': 2,
    'clock': clock,
    'entries': [for (final e in entries) e.toJson()],
    if (removals.isNotEmpty)
      'removed': removalsToJson(removals, removalRevisions),
  });
}
