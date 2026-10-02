import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/services.dart';
import 'isolate_runtime.dart';
import 'models.dart';

final downloadRuntimeProvider = Provider<DownloadIsolateRuntime>((ref) {
  final runtime = DownloadIsolateRuntime(
    stateFile: ref.watch(appPathsProvider).downloadsFile.path,
  );
  ref.onDispose(() {
    unawaited(runtime.dispose());
  });
  return runtime;
});

/// Engine state for future consumers; no widgets or toast dependencies.
final downloadsProvider = StreamProvider<List<DownloadItem>>((ref) async* {
  final runtime = ref.watch(downloadRuntimeProvider);
  await runtime.initialize();
  yield runtime.currentState;
  yield* runtime.stateStream;
});
