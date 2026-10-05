import 'dart:convert';

import '../watching/models.dart';

/// Thrown for a backup the viewer can act on; the message is shown as is.
class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The watch history and what the viewer removed from it. Removals travel
/// with it so a backup restored elsewhere does not bring them back.
class WatchSnapshot {
  const WatchSnapshot(this.entries, this.removals);

  /// Newest first.
  final List<WatchEntry> entries;

  /// When each movie or series (by [WatchEntry.key]) was last removed.
  final Map<String, DateTime> removals;

  /// How long a removal is remembered; backups older than this may revive
  /// what it removed.
  static const removalMemory = Duration(days: 90);

  /// Both as one: each movie or episode keeps its most recently updated
  /// record, the oldest go past [capacity], and what either side removed
  /// stays removed unless watched again since.
  WatchSnapshot merge(WatchSnapshot other, {required int capacity}) {
    final cutoff = DateTime.now().subtract(removalMemory);
    final removed = <String, DateTime>{};
    for (final r in [...removals.entries, ...other.removals.entries]) {
      final held = removed[r.key];
      if (r.value.isAfter(cutoff) && (held == null || r.value.isAfter(held))) {
        removed[r.key] = r.value;
      }
    }
    final newest = <String, WatchEntry>{};
    for (final e in [...entries, ...other.entries]) {
      final held = newest[e.id];
      if (held == null || e.updatedAt.isAfter(held.updatedAt)) newest[e.id] = e;
    }
    final kept = newest.values.where((e) {
      final at = removed[e.key];
      return at == null || at.isBefore(e.updatedAt);
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return WatchSnapshot(kept.take(capacity).toList(), removed);
  }

  /// Whether [other] holds the same records and removals.
  bool matches(WatchSnapshot other) {
    if (entries.length != other.entries.length ||
        removals.length != other.removals.length) {
      return false;
    }
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].id != other.entries[i].id ||
          entries[i].updatedAt != other.entries[i].updatedAt) {
        return false;
      }
    }
    return removals.entries.every((r) => other.removals[r.key] == r.value);
  }
}

/// Watch history as a file: the same JSON in an exported file and in Drive.
abstract final class WatchBackup {
  static const _format = 'sentorr-watch-history';
  static const _version = 1;

  static String encode(WatchSnapshot snapshot, {DateTime? at}) =>
      '${const JsonEncoder.withIndent('  ').convert({'format': _format, 'version': _version, 'exportedAt': (at ?? DateTime.now()).toUtc().toIso8601String(), ...json(snapshot)})}\n';

  /// The history's own fields, to sit inside a larger file.
  static Map<String, dynamic> json(WatchSnapshot snapshot) => {
    'entries': [for (final e in snapshot.entries) e.toJson()],
    'removed': removalsToJson(snapshot.removals),
  };

  /// Throws [BackupException] when [source] is not a Sentorr backup; a bad
  /// entry inside one is skipped, as when loading the history file.
  static WatchSnapshot decode(String source) {
    final Object? parsed;
    try {
      parsed = jsonDecode(source);
    } on FormatException {
      throw const BackupException('That file is not a Sentorr backup.');
    }
    if (parsed is! Map<String, dynamic> || parsed['format'] != _format) {
      throw const BackupException('That file is not a Sentorr backup.');
    }
    final version = parsed['version'];
    if (version is! int || version > _version) {
      throw const BackupException(
        'That backup is from a newer Sentorr. Update the app to restore it.',
      );
    }
    return fromJson(parsed);
  }

  /// Throws [BackupException] when there is no history in [parsed].
  static WatchSnapshot fromJson(Object? parsed) {
    final entries = parsed is Map<String, dynamic> ? parsed['entries'] : null;
    if (entries is! List) {
      throw const BackupException('That backup has no watch history in it.');
    }
    return WatchSnapshot([
      ...entries.map(WatchEntry.fromJson).nonNulls,
    ], removalsFromJson((parsed as Map<String, dynamic>)['removed']));
  }
}

List<Map<String, String>> removalsToJson(Map<String, DateTime> removals) => [
  for (final r in removals.entries)
    {'key': r.key, 'at': r.value.toUtc().toIso8601String()},
];

/// Skips what is not a removal, so one bad record costs nothing else.
Map<String, DateTime> removalsFromJson(Object? json) => {
  if (json is List)
    for (final r in json)
      if (r case {'key': final String key, 'at': final String at})
        if (DateTime.tryParse(at) case final time?) key: time.toLocal(),
};
