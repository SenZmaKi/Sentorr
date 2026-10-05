import 'dart:convert';

import '../following/snapshot.dart';
import 'watch_backup.dart';

/// What a backup keeps so that, on another device, the viewer picks up where
/// they left off: watch history and followed series. Preferences stay per
/// device, and downloaded files are not in it.
class BackupBundle {
  const BackupBundle({required this.watch, required this.following});

  final WatchSnapshot watch;
  final FollowedSnapshot following;

  static const _format = 'sentorr-backup';
  static const _version = 1;

  /// Whether [other] holds the same records, for skipping a pointless upload.
  bool matches(BackupBundle other) =>
      watch.matches(other.watch) &&
      _shared(following) == _shared(other.following);

  /// Followed series as devices share them: each keeps its own choice of
  /// downloading by itself, so that is left out, or two devices would
  /// rewrite the backup at each other forever.
  static String _shared(FollowedSnapshot f) {
    final json = f.toJson();
    return jsonEncode({
      ...json,
      'series': [
        for (final s in json['series'] as List)
          {...(s as Map<String, dynamic>)}..remove('autoDownload'),
      ],
    });
  }

  String encode({DateTime? at}) =>
      '${const JsonEncoder.withIndent('  ').convert({'format': _format, 'version': _version, 'exportedAt': (at ?? DateTime.now()).toUtc().toIso8601String(), 'watch': WatchBackup.json(watch), 'following': following.toJson()})}\n';

  /// Throws [BackupException] when [source] is not a Sentorr backup. A
  /// history-only file from before backups held more still reads.
  static BackupBundle decode(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      throw const BackupException('That file is not a Sentorr backup.');
    }
    if (json is Map<String, dynamic> && json['format'] != _format) {
      return BackupBundle(
        watch: WatchBackup.decode(source),
        following: const FollowedSnapshot([], {}),
      );
    }
    if (json is! Map<String, dynamic>) {
      throw const BackupException('That file is not a Sentorr backup.');
    }
    final version = json['version'];
    if (version is! int || version > _version) {
      throw const BackupException(
        'That backup is from a newer Sentorr. Update the app to restore it.',
      );
    }
    return BackupBundle(
      watch: WatchBackup.fromJson(json['watch']),
      following: FollowedSnapshot.fromJson(json['following']),
    );
  }
}
