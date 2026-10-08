import '../following/models.dart';
import '../lists/models.dart';
import '../watching/models.dart';
import 'watch_backup.dart';

/// Drive must not compact away records its codecs silently skipped. Manual
/// imports may recover valid records, but shared snapshots are all-or-nothing.
void validateBackupRecords({
  required Map<String, dynamic> watch,
  Map<String, dynamic>? following,
  Map<String, dynamic>? lists,
}) {
  try {
    for (final record in watch['entries'] as List) {
      _record(record, WatchEntry.fromJson);
    }
    _removals(watch['removed'], 'key');
    if (following != null) {
      for (final record in following['series'] as List) {
        _record(record, FollowedSeries.fromJson);
        final versions = (record as Map)['versions'];
        if (versions != null) {
          if (versions is! List) _invalid();
          for (final version in versions) {
            _record(version, FollowedSeries.fromJson);
          }
        }
      }
      _removals(following['removed'], 'id');
    }
    if (lists != null) {
      for (final record in lists['entries'] as List) {
        _record(record, ListEntry.fromJson);
      }
    }
  } on TypeError {
    _invalid();
  } on FormatException {
    _invalid();
  }
}

void _record(Object? value, Object? Function(Object?) read) {
  if (value is! Map<String, dynamic> || read(value) == null) _invalid();
  for (final key in ['revision', 'notifyRevision', 'notifiedRevision']) {
    if (value.containsKey(key) &&
        (value[key] is! int || (value[key] as int) < 0)) {
      _invalid();
    }
  }
}

void _removals(Object? value, String key) {
  if (value == null) return; // Legacy history snapshots may omit removals.
  if (value is! List) _invalid();
  for (final record in value) {
    if (record is! Map<String, dynamic> ||
        record[key] is! String ||
        record['at'] is! String ||
        DateTime.tryParse(record['at'] as String) == null ||
        (record.containsKey('revision') &&
            (record['revision'] is! int || (record['revision'] as int) < 0))) {
      _invalid();
    }
  }
}

Never _invalid() => throw const BackupException(
  'That backup contains invalid records. Nothing was synced or overwritten.',
);
