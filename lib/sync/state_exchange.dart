import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../following/notifier.dart';
import '../watching/notifier.dart';
import 'payload.dart';
import 'shared_library.dart';

Map<String, dynamic> localSyncPayload(Ref ref) => {
  ...SyncPayload(
    watch: ref.read(watchHistoryProvider.notifier).snapshot,
    following: ref.read(followedSeriesProvider.notifier).snapshot,
  ).toJson(),
  'library': sharedLibrary(ref).toJson(),
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
}
