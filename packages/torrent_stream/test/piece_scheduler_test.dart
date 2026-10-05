import 'package:test/test.dart';
import 'package:torrent_stream/src/engine/cancellation.dart';
import 'package:torrent_stream/src/engine/piece_scheduler.dart';

import 'read_support.dart';

void main() {
  test('repeated demand in a piece avoids recomputing priority windows', () {
    final handle = TestHandle();
    var baseReads = 0;
    final scheduler = PieceScheduler(
      handle,
      base: (_) {
        baseReads++;
        return 0;
      },
    );
    final owner = Cancellation();
    scheduler.demand(owner, 2, 20, 3);
    final reads = baseReads, calls = handle.calls;
    for (var i = 0; i < 100; i++) {
      scheduler.demand(owner, 2, 20, 3);
    }
    expect(baseReads, reads);
    expect(handle.calls, calls);
    scheduler.demand(owner, 3, 20, 3);
    expect(handle.priorities[2], 0);
    expect(handle.priorities[3], 7);
    expect(handle.priorities[6], 1);
  });

  test('unchanged demand still removes cancelled consumers priorities', () {
    final handle = TestHandle();
    final scheduler = PieceScheduler(handle);
    final active = Cancellation(), cancelled = Cancellation();
    scheduler.demand(active, 1, 20, 2);
    scheduler.demand(cancelled, 10, 20, 2);
    cancelled.cancel();
    scheduler.demand(active, 1, 20, 2);
    expect(handle.priorities[10], 0);
    expect(handle.deadlines.containsKey(10), false);
    expect(scheduler.needs(10), false);
    expect(handle.priorities[1], 7);
  });

  test('reapply and release still restore changed file priorities', () {
    final handle = TestHandle();
    var base = 0;
    final scheduler = PieceScheduler(handle, base: (_) => base);
    final owner = Cancellation();
    scheduler.demand(owner, 1, 20, 2);
    base = 4;
    scheduler.reapply();
    expect(handle.priorities[2], 4);
    scheduler.release(owner);
    expect(handle.priorities[1], 4);
    expect(handle.deadlines, isEmpty);
    final calls = handle.calls;
    scheduler.release(owner);
    scheduler.prune();
    expect(handle.calls, calls);
  });
}
