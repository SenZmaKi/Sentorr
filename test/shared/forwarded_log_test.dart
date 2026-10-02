import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:sentorr/shared/log.dart';

void main() {
  test('a worker isolate logs through the main isolate', () async {
    final records = <LogRecord>[];
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen(records.add);
    final inbox = ReceivePort();
    await Isolate.spawn(_worker, inbox.sendPort);
    await for (final message in inbox) {
      if (message == 'done') break;
      expect(writeForwardedLog(message), isTrue);
    }
    inbox.close();
    await subscription.cancel();

    expect(records.map((r) => (r.level, r.loggerName, r.message)), [
      (Level.INFO, 'sentorr.worker', 'Queued Dune'),
      (Level.WARNING, 'sentorr.worker', 'Tracker failed'),
    ]);
    expect(records.last.error, 'Bad state: offline');
    expect(records.last.stackTrace, isNotNull);
    expect(writeForwardedLog({'state': []}), isFalse);
  });
}

Future<void> _worker(SendPort out) async {
  forwardLogsTo(out);
  final log = Logger('sentorr.worker');
  log.info('Queued Dune');
  log.warning('Tracker failed', StateError('offline'), StackTrace.current);
  // Records are delivered asynchronously; let them go out first.
  await Future<void>.delayed(Duration.zero);
  out.send('done');
}
