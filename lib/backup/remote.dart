import 'backup_bundle.dart';

/// A backup as found remotely, and which version of the file it was.
class RemoteBackup {
  const RemoteBackup(
    this.bundle,
    this.revision, {
    this.needsPublication = false,
  });

  /// Consolidate legacy names or multiple validated snapshots even when unchanged.
  final bool needsPublication;
  final BackupBundle bundle;

  /// Identifies this version of the file, to notice another device
  /// replacing it.
  final String? revision;
}

/// Another device replaced the remote backup after it was read.
class BackupConflict implements Exception {
  const BackupConflict();
}

/// Where the shared backup state lives.
abstract interface class BackupRemote {
  /// Null when nothing was backed up yet.
  Future<RemoteBackup?> download();

  /// Publishes state based on [basedOn]. A mutable backend must atomically
  /// refuse an outdated revision with [BackupConflict]. An immutable backend
  /// may publish concurrently, retaining every unobserved snapshot.
  Future<void> upload(BackupBundle bundle, {required String? basedOn});
}
