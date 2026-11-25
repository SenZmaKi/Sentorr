import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import '../shared/persistence/json_file_store.dart';

final smartDownloadsStoreProvider = Provider<JsonFileStore>(
  (ref) => JsonFileStore(ref.watch(appPathsProvider).smartDownloadsFile),
);

/// Items the viewer removed from smart downloads, by IMDb id, so they are
/// not picked again. Loaded on first use.
class SmartDismissals {
  SmartDismissals(this._store);
  final JsonFileStore _store;
  Set<String>? _ids;

  /// Most recent last; older ones are forgotten past this many.
  static const capacity = 500;

  Future<Set<String>> load() async {
    if (_ids case final ids?) return ids;
    final json = await _store.read();
    final ids = json?['dismissed'];
    return _ids = {if (ids is List) ...ids.whereType<String>()};
  }

  Future<void> add(String id) async {
    final ids = await load();
    ids
      ..remove(id)
      ..add(id);
    while (ids.length > capacity) {
      ids.remove(ids.first);
    }
    await _store.write({
      'version': 1,
      'dismissed': [...ids],
    });
  }
}

final smartDismissalsProvider = Provider<SmartDismissals>(
  (ref) => SmartDismissals(ref.watch(smartDownloadsStoreProvider)),
);
