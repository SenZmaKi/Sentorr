import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../following/notifier.dart';
import '../watching/notifier.dart';
import 'backup_bundle.dart';

/// Reads what a backup keeps from the app and folds a backup back in.
final backupDataProvider = Provider<BackupData>((ref) => BackupData(ref));

class BackupData {
  BackupData(this._ref);
  final Ref _ref;

  BackupBundle current() => BackupBundle(
    watch: _ref.read(watchHistoryProvider.notifier).snapshot,
    following: _ref.read(followedSeriesProvider.notifier).snapshot,
  );

  /// Merges [bundle] in: each keeps the newer record of every title, and
  /// what either side removed stays removed. Preferences are not part of it.
  Future<void> apply(BackupBundle bundle) async {
    await _ref.read(watchHistoryProvider.notifier).merge(bundle.watch);
    await _ref.read(followedSeriesProvider.notifier).merge(bundle.following);
  }
}
