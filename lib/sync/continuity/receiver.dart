import 'dart:async';

import '../client.dart';
import '../media_proxy.dart';
import 'session.dart';

/// A single handoff transaction. Preparation must leave playback paused;
/// failures before take leave the source untouched. The same ID is reused
/// after a lost acknowledgement so the source pause remains idempotent.
Future<void> receiveContinuity({
  required PeerClient client,
  required PeerRoute route,
  required String sessionId,
  required String handoffId,
  required bool Function() current,
  required Future<void> Function(ContinuitySession) prepare,
  required Future<void> Function(Duration) start,
}) async {
  void check() {
    if (!current()) throw const PeerException('Handoff cancelled');
  }

  final answer = await client.call(
    route.address,
    route.fingerprint,
    '/v1/continuity',
  );
  check();
  final session = ContinuitySession.fromResponse(answer);
  if (session == null || session.id != sessionId) {
    throw const PeerException('Playback has changed. Try again.');
  }
  await prepare(session);
  check();
  Map<String, dynamic>? taken;
  for (var attempt = 0; attempt < 2; attempt++) {
    check();
    try {
      taken = await client.call(
        route.address,
        route.fingerprint,
        '/v1/continuity/take',
        body: {'session': sessionId, 'handoff': handoffId},
        timeout: const Duration(seconds: 5),
      );
      break;
    } on PeerException catch (error) {
      if (error.status != null || attempt == 1) rethrow;
    } on TimeoutException {
      if (attempt == 1) rethrow;
    }
  }
  check();
  final position = taken?['position'];
  if (position is! int ||
      position < 0 ||
      position > session.duration.inMilliseconds) {
    throw const FormatException('Invalid handoff position');
  }
  await start(Duration(milliseconds: position));
}
