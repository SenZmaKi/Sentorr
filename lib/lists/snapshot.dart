import 'dart:convert';

import '../shared/state_clock.dart';
import 'models.dart';

/// Every title on the viewer's lists, removals included, as one device
/// holds them; merging two gives every device the same lists.
class ListsSnapshot {
  const ListsSnapshot(this.entries);

  /// Most recently changed first.
  final List<ListEntry> entries;

  /// How long a removal is remembered; a device away for longer may bring
  /// the title back.
  static const removalMemory = Duration(days: 90);

  /// Each title keeps its latest change from either side.
  ListsSnapshot merge(ListsSnapshot other) {
    final latest = <String, ListEntry>{};
    for (final e in [...entries, ...other.entries]) {
      final held = latest[e.id];
      if (held == null || compareListEntries(e, held) > 0) latest[e.id] = e;
    }
    return ListsSnapshot.of(latest.values);
  }

  /// [values] newest first, without removals older than [removalMemory].
  static ListsSnapshot of(Iterable<ListEntry> values) {
    final cutoff = DateTime.now().subtract(removalMemory);
    return ListsSnapshot(
      values.where((e) => !e.removed || e.updatedAt.isAfter(cutoff)).toList()
        ..sort((a, b) => compareListEntries(b, a)),
    );
  }

  /// Whether [other] holds the same records.
  bool matches(ListsSnapshot other) =>
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  Map<String, dynamic> toJson() => {
    'entries': [for (final e in entries) e.toJson()],
  };

  /// Skips what is not a record, so one bad one costs nothing else.
  static ListsSnapshot fromJson(Object? json) {
    final entries = json is Map<String, dynamic> ? json['entries'] : null;
    return ListsSnapshot.of([
      if (entries is List) ...entries.map(ListEntry.fromJson).nonNulls,
    ]);
  }
}

/// Total ordering, including a deterministic winner for revision ties.
int compareListEntries(ListEntry a, ListEntry b) {
  final time = compareRevision(
    a.revision,
    a.updatedAt,
    b.revision,
    b.updatedAt,
  );
  if (time != 0) return time;
  final id = a.id.compareTo(b.id);
  return id != 0
      ? id
      : jsonEncode(a.toJson()).compareTo(jsonEncode(b.toJson()));
}
