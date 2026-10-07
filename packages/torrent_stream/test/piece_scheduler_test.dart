import 'package:test/test.dart';
import 'package:torrent_stream/src/engine/cancellation.dart';
import 'package:torrent_stream/src/engine/piece_scheduler.dart';

import 'read_support.dart';

void main() {
  test(
    'disk prefetch survives HTTP release and moves without urgent deadlines',
    () {
      final handle = TestHandle(pieceLength: 1024 * 1024);
      final scheduler = PieceScheduler(handle);
      final disk = Cancellation(), http = Cancellation();
      scheduler.demand(disk, 0, 30, 20, urgent: false);
      expect(handle.deadlines, isEmpty);
      scheduler.demand(http, 0, 30, 1);
      expect(handle.priorities[0], 7);
      scheduler.release(http);
      expect(handle.priorities[0], 5);
      expect(handle.priorities[20], 5);
      scheduler.demand(disk, 10, 30, 20, urgent: false);
      expect(handle.priorities[0], 0);
      expect(handle.priorities[30], 5);
      scheduler.release(disk);
      expect(handle.priorities[30], 0);
    },
  );
  test('deadlines cover a bounded upcoming window and move on seek', () {
    final handle = TestHandle(pieceLength: 1024 * 1024);
    final scheduler = PieceScheduler(handle);
    final owner = Cancellation();
    scheduler.demand(owner, 0, 30, 8);
    expect(handle.deadlines, {0: 0, 1: 500});
    expect(handle.priorities[2], 5);
    scheduler.demand(owner, 20, 30, 8);
    expect(handle.deadlines, {20: 0, 21: 500});
    expect(handle.priorities[0], 0);
    scheduler.release(owner);
    expect(handle.deadlines, isEmpty);
    expect(handle.priorities[20], 0);
  });
  test(
    'video read-ahead outranks sidecars and restores their base on release',
    () {
      final handle = TestHandle(pieceLength: 1024 * 1024);
      final scheduler = PieceScheduler(handle, base: (_) => 4);
      final owner = Cancellation();
      scheduler.demand(owner, 0, 30, 8);
      expect(handle.priorities[0], 7);
      expect(handle.priorities[2], 5);
      scheduler.release(owner);
      expect(handle.priorities[2], 4);
    },
  );
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
    expect(handle.priorities[6], 7);
    expect(handle.deadlines, {3: 0, 4: 500, 5: 1000, 6: 1500});
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
    expect(handle.priorities[2], 7);
    scheduler.release(owner);
    expect(handle.priorities[1], 4);
    expect(handle.deadlines, isEmpty);
    final calls = handle.calls;
    scheduler.release(owner);
    scheduler.prune();
    expect(handle.calls, calls);
  });
}
