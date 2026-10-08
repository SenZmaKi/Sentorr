import '../shared/persistence/json_file_store.dart';
import 'models.dart';
import 'snapshot.dart';

class WatchListsRepository {
  WatchListsRepository(this.store);
  final JsonFileStore store;
  int clock = 0;

  /// Removals included, most recently changed first; null before anything
  /// was ever saved.
  Future<List<ListEntry>?> load() async {
    final json = await store.read();
    clock = json?['clock'] is int ? json!['clock'] as int : 0;
    if (json == null) return null;
    return ListsSnapshot.fromJson(json).entries;
  }

  Future<void> save(List<ListEntry> entries) => store.write({
    'version': 1,
    'clock': clock,
    ...ListsSnapshot(entries).toJson(),
  });
}
