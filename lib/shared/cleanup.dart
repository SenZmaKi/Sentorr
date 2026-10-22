import 'dart:async';

import 'package:logging/logging.dart';

/// Every owned resource gets its cleanup even when another stage fails.
/// Errors remain in diagnostics; shutdown must still release native resources.
Future<void> cleanupAll(Iterable<FutureOr<void> Function()> stages) async {
  for (final stage in stages) {
    try {
      await stage();
    } catch (error, stack) {
      Logger('sentorr.cleanup').severe('Cleanup stage failed', error, stack);
    }
  }
}
