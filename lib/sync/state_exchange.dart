import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'payload.dart';
import 'shared_library.dart';
import 'user_state.dart';

Future<Map<String, dynamic>> localSyncPayload(Ref ref) async => {
  ...ref.read(userStateSyncProvider).current().toJson(),
  'library': (await sharedLibrary(ref)).toJson(),
};

Future<void> mergePeerState(
  Ref ref,
  SyncPayload incoming,
  bool Function() valid,
) => ref.read(userStateSyncProvider).merge(incoming, valid: valid);
