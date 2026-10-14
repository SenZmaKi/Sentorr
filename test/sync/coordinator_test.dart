import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/sync/coordinator.dart';

void main() {
  test(
    'overlapping requests share a drain and coalesce into one follow-up',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      var runs = 0, active = 0, peak = 0;
      final coordinator = SyncCoordinator(
        active: () => true,
        action: () async {
          runs++;
          active++;
          if (active > peak) peak = active;
          if (runs == 1) {
            entered.complete();
            await release.future;
          }
          active--;
        },
      );
      addTearDown(coordinator.dispose);
      final first = coordinator.run();
      await entered.future;
      final second = coordinator.run(), third = coordinator.run();
      expect(identical(first, second), isTrue);
      expect(identical(first, third), isTrue);
      coordinator.changed();
      release.complete();
      await first;
      expect(runs, 2);
      expect(peak, 1);
      expect(coordinator.running, isFalse);
    },
  );

  test('first action runs once and changes use the normal action', () async {
    var initial = 0, ordinary = 0;
    late SyncCoordinator coordinator;
    coordinator = SyncCoordinator(
      active: () => true,
      action: () async => ordinary++,
    );
    addTearDown(coordinator.dispose);
    await coordinator.run(
      first: () async {
        initial++;
        coordinator.changed();
      },
    );
    expect(initial, 1);
    expect(ordinary, 1);
    coordinator.changed();
    expect(ordinary, 1); // Idle changes do not invent a transport policy.
  });

  test('invalidated old run cannot follow up or clear a replacement', () async {
    final gate = Completer<void>();
    var oldRuns = 0, newRuns = 0;
    final old = SyncCoordinator(
      active: () => true,
      action: () async {
        oldRuns++;
        await gate.future;
      },
    );
    final replacement = SyncCoordinator(
      active: () => true,
      action: () async => newRuns++,
    );
    addTearDown(replacement.dispose);
    final pending = old.run();
    old.changed();
    old.dispose();
    await replacement.run();
    gate.complete();
    await pending;
    await replacement.run();
    expect(oldRuns, 1);
    expect(newRuns, 2);
  });

  test('separate peer coordinators can run concurrently', () async {
    final gate = Completer<void>();
    var active = 0;
    Future<void> action() async {
      active++;
      await gate.future;
      active--;
    }

    final a = SyncCoordinator(active: () => true, action: action);
    final b = SyncCoordinator(active: () => true, action: action);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final first = a.run(), second = b.run();
    expect(active, 2);
    gate.complete();
    await Future.wait([first, second]);
    expect(active, 0);
  });

  test('transport invalidation stops a queued follow-up', () async {
    final gate = Completer<void>();
    var valid = true, runs = 0;
    final coordinator = SyncCoordinator(
      active: () => valid,
      action: () async {
        runs++;
        await gate.future;
      },
    );
    addTearDown(coordinator.dispose);
    final pending = coordinator.run();
    coordinator.changed();
    valid = false;
    gate.complete();
    await pending;
    await coordinator.run();
    expect(runs, 1);
  });

  test('failed action releases the drain and later calls can retry', () async {
    var runs = 0;
    final coordinator = SyncCoordinator(
      active: () => true,
      action: () async {
        if (++runs == 1) throw StateError('offline');
      },
    );
    addTearDown(coordinator.dispose);
    await expectLater(coordinator.run(), throwsStateError);
    expect(coordinator.running, isFalse);
    await coordinator.run();
    expect(runs, 2);
  });

  testWidgets('earliest deadline wins and disposal cancels scheduled work', (
    tester,
  ) async {
    var runs = 0;
    final coordinator = SyncCoordinator(
      active: () => true,
      action: () async => runs++,
    );
    coordinator.schedule(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    coordinator.schedule(const Duration(seconds: 2));
    coordinator.schedule(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 2));
    expect(runs, 1);
    coordinator.repeat(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    expect(runs, 2);
    coordinator.schedule(const Duration(seconds: 1));
    coordinator.dispose();
    await tester.pump(const Duration(seconds: 20));
    expect(runs, 2);
  });
}
