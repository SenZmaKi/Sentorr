import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../following/notifier.dart';
import '../lists/notifier.dart';
import '../watching/notifier.dart';
import 'payload.dart';
import 'shared_library.dart';

Future<Map<String, dynamic>> localSyncPayload(Ref ref) async => {
  ...SyncPayload(
    watch: ref.read(watchHistoryProvider.notifier).snapshot,
    following: ref.read(followedSeriesProvider.notifier).snapshot,
    lists: ref.read(watchListsProvider.notifier).snapshot,
  ).toJson(),
  'library': (await sharedLibrary(ref)).toJson(),
};

Future<void> mergePeerState(
  Ref ref,
  SyncPayload incoming,
  bool Function() valid,
) async {
  if (!valid()) return;
  await ref.read(watchHistoryProvider.notifier).merge(incoming.watch);
  if (!valid()) return;
  await ref.read(followedSeriesProvider.notifier).merge(incoming.following);
  if (!valid()) return;
  await ref.read(watchListsProvider.notifier).merge(incoming.lists);
}
