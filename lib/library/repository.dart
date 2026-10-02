import '../shared/persistence/json_file_store.dart';
import 'models.dart';

class LibraryRepository {
  LibraryRepository(this.store);
  final JsonFileStore store;

  Future<List<LibraryEntry>> load() async {
    final json = await store.read();
    final entries = json?['entries'];
    if (entries is! List) return [];
    return [...entries.map(LibraryEntry.fromJson).nonNulls];
  }

  Future<void> save(List<LibraryEntry> entries) => store.write({
    'version': 1,
    'entries': [for (final e in entries) e.toJson()],
  });
}
