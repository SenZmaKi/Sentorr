import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../following/notifier.dart';
import '../lists/notifier.dart';
import '../watching/notifier.dart';
import 'payload.dart';

/// Transport-independent user state shared by LAN peers and cloud backups.
/// Domain notifiers own conflict resolution, tombstones and durable writes.
final userStateSyncProvider = Provider<UserStateSync>(UserStateSync.new);

class UserStateSync {
  UserStateSync(this._ref);
  final Ref _ref;

  /// Both transports observe the same user-owned domains.
  void listen(Ref owner, void Function() changed) {
    owner.listen(watchHistoryProvider, (_, _) => changed());
    owner.listen(followedSeriesProvider, (_, _) => changed());
    owner.listen(watchListsProvider, (_, _) => changed());
  }

  SyncPayload current() => SyncPayload(
    watch: _ref.read(watchHistoryProvider.notifier).snapshot,
    following: _ref.read(followedSeriesProvider.notifier).snapshot,
    lists: _ref.read(watchListsProvider.notifier).snapshot,
  );

  /// Check ownership between writes so stale peer requests stop merging.
  Future<void> merge(SyncPayload incoming, {bool Function()? valid}) async {
    bool active() => _ref.mounted && (valid?.call() ?? true);
    if (!active()) return;
    await _ref.read(watchHistoryProvider.notifier).merge(incoming.watch);
    if (!active()) return;
    await _ref.read(followedSeriesProvider.notifier).merge(incoming.following);
    if (!active()) return;
    await _ref.read(watchListsProvider.notifier).merge(incoming.lists);
  }
}
