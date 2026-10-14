import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/payload.dart';
import '../sync/user_state.dart';
import 'backup_bundle.dart';

/// Adapts the shared user state to the versioned file/Drive backup format.
final backupDataProvider = Provider<BackupData>((ref) => BackupData(ref));

class BackupData {
  BackupData(this._ref);
  final Ref _ref;

  BackupBundle current() {
    final state = _ref.read(userStateSyncProvider).current();
    return BackupBundle(
      watch: state.watch,
      following: state.following,
      lists: state.lists,
    );
  }

  Future<void> apply(BackupBundle bundle) => _ref
      .read(userStateSyncProvider)
      .merge(
        SyncPayload(
          watch: bundle.watch,
          following: bundle.following,
          lists: bundle.lists,
        ),
      );
}
