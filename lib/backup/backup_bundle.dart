import 'dart:convert';

import '../following/snapshot.dart';
import '../lists/snapshot.dart';
import '../shared/state_formats.dart';
import 'watch_backup.dart';
import 'backup_validation.dart';

/// What a backup keeps so that, on another device, the viewer picks up where
/// they left off: watch history, followed series and watch lists.
/// Preferences stay per device, and downloaded files are not in it.
class BackupBundle {
  const BackupBundle({
    required this.watch,
    required this.following,
    this.lists = const ListsSnapshot([]),
  });

  final WatchSnapshot watch;
  final FollowedSnapshot following;
  final ListsSnapshot lists;

  static const _format = 'sentorr-backup';
  static const _version = 3;

  /// Whether [other] holds the same records, for skipping a pointless upload.
  bool matches(BackupBundle other) =>
      watch.matches(other.watch) &&
      lists.matches(other.lists) &&
      _shared(following) == _shared(other.following);

  /// Followed series as devices share them: each keeps its own choice of
  /// downloading by itself, so that is left out, or two devices would
  /// rewrite the backup at each other forever.
  static String _shared(FollowedSnapshot f) {
    final json = f.canonicalJson();
    return jsonEncode({
      ...json,
      'series': [
        for (final s in json['series'] as List)
          {...(s as Map<String, dynamic>)}..remove('autoDownload'),
      ],
    });
  }

  String encode({DateTime? at}) =>
      '${const JsonEncoder.withIndent('  ').convert({'format': _format, 'version': _version, 'formats': StateFormats.versions, 'exportedAt': (at ?? DateTime.now()).toUtc().toIso8601String(), 'watch': WatchBackup.json(watch), 'following': following.toJson(), 'lists': lists.toJson()})}\n';

  /// Throws [BackupException] when [source] is not a Sentorr backup. A
  /// history-only file from before backups held more still reads.
  static BackupBundle decode(String source, {bool strict = false}) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      throw const BackupException('That file is not a Sentorr backup.');
    }
    if (json is Map<String, dynamic> && json['format'] != _format) {
      final watch = WatchBackup.decode(source);
      if (strict) validateBackupRecords(watch: json);
      return BackupBundle(
        watch: watch,
        following: const FollowedSnapshot([], {}),
      );
    }
    if (json is! Map<String, dynamic>) {
      throw const BackupException('That file is not a Sentorr backup.');
    }
    final version = json['version'];
    if (version is! int || version < 1 || version > _version) {
      throw const BackupException(
        'That backup is from a newer Sentorr. Update the app to restore it.',
      );
    }
    if (version >= 3 && !StateFormats.accepts(json['formats'])) {
      throw const BackupException(
        'That backup uses incompatible data formats. Update Sentorr before syncing it.',
      );
    }
    _validateShape(json, requireLists: version >= 3);
    if (strict) {
      validateBackupRecords(
        watch: json['watch'] as Map<String, dynamic>,
        following: json['following'] as Map<String, dynamic>,
        lists: json['lists'] as Map<String, dynamic>?,
      );
    }
    return BackupBundle(
      watch: WatchBackup.fromJson(json['watch']),
      following: FollowedSnapshot.fromJson(json['following']),
      lists: ListsSnapshot.fromJson(json['lists']),
    );
  }

  static void _validateShape(
    Map<String, dynamic> json, {
    required bool requireLists,
  }) {
    final watch = json['watch'];
    final following = json['following'];
    final lists = json['lists'];
    if (watch is! Map<String, dynamic> ||
        watch['entries'] is! List ||
        watch['removed'] is! List ||
        following is! Map<String, dynamic> ||
        following['series'] is! List ||
        following['removed'] is! List ||
        (requireLists && lists == null) ||
        (lists != null &&
            (lists is! Map<String, dynamic> || lists['entries'] is! List))) {
      throw const BackupException(
        'That backup has an invalid data structure. Nothing was synced.',
      );
    }
  }
}
