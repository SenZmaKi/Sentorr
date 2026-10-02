import 'dart:async';
import 'dart:isolate';

import '../engine/lab_session.dart';

void engineWorker(SendPort host) {
  final commands = ReceivePort();
  host.send(commands.sendPort);
  LabSession? session;
  Future<void> queue = Future.value();
  commands.listen((dynamic message) {
    final command = message as Map;
    if (command['op'] == 'close') session?.lifetime.cancel();
    queue = queue.then((_) async {
      final reply = command['reply'] as SendPort;
      try {
        Object? result;
        switch (command['op']) {
          case 'open':
            await session?.close();
            session = LabSession((event) => host.send(event));
            result = await session!.open(
              command['input'] as String,
              controlled: command['controlled'] as bool,
              downloadMbps: command['downloadMbps'] as int? ?? 40,
              readAheadMiB: command['readAheadMiB'] as int? ?? 16,
            );
          case 'select':
            result = await session!.select(command['index'] as int);
          case 'seek':
            session?.prepareSeek();
          case 'pause-transfer':
            session?.pauseTransfer(command['paused'] as bool);
          case 'pause-seed':
            session?.pauseSeed(command['paused'] as bool);
          case 'close':
            await session?.close();
            session = null;
        }
        reply.send({'result': result});
      } catch (error, stack) {
        reply.send({'error': '$error', 'stack': '$stack'});
        if (command['op'] == 'open') {
          await session?.close();
          session = null;
        }
      }
    });
  });
}
