import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:torrent_stream/src/engine/cancellation.dart';

void main() {
  test('cancelled wait observes a pending socket flush failure', () async {
    final cancellation = Cancellation()..cancel();
    final flush = Completer<void>();
    expect(
      () => cancellation.wait(flush.future),
      throwsA(isA<ReadCancelled>()),
    );
    flush.completeError(const SocketException('Connection reset by peer'));
    await Future<void>.delayed(Duration.zero);
  });
}
