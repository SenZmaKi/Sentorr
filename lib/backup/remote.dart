import 'backup_bundle.dart';

/// A backup as found remotely, and which version of the file it was.
class RemoteBackup {
  const RemoteBackup(this.bundle, this.revision);
  final BackupBundle bundle;

  /// Identifies this version of the file, to notice another device
  /// replacing it.
  final String? revision;
}

/// Another device replaced the remote backup after it was read.
class BackupConflict implements Exception {
  const BackupConflict();
}

/// Where the one shared backup lives.
abstract interface class BackupRemote {
  /// Null when nothing was backed up yet.
  Future<RemoteBackup?> download();

  /// Replaces the remote backup, but only if it is still the version
  /// [basedOn] was read from (null: still none). Throws [BackupConflict]
  /// otherwise, so a device never overwrites what it has not merged.
  Future<void> upload(BackupBundle bundle, {required String? basedOn});
}
