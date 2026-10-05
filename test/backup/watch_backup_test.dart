import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/backup/watch_backup.dart';
import 'package:sentorr/watching/models.dart';
import 'package:sentorr/watching/notifier.dart';

import '../support/fake_history.dart';
import '../support/fake_imdb.dart';

final _now = DateTime.now();
WatchEntry _entry(int n, Duration ago, {int minutes = 10}) => WatchEntry(
  title: fakeTitle(n),
  position: Duration(minutes: minutes),
  duration: const Duration(minutes: 90),
  updatedAt: _now.subtract(ago),
);

WatchSnapshot _snap(List<WatchEntry> e, [Map<String, DateTime>? removed]) =>
    WatchSnapshot(e, removed ?? {});

void main() {
  group('WatchBackup', () {
    test('round-trips entries and removals', () {
      final removed = {'tt9': _now.subtract(const Duration(days: 1))};
      final decoded = WatchBackup.decode(
        WatchBackup.encode(_snap([_entry(1, Duration.zero)], removed)),
      );
      expect(decoded.entries.single.id, 'tt1');
      expect(decoded.entries.single.position, const Duration(minutes: 10));
      expect(decoded.removals.keys, ['tt9']);
    });

    test('refuses what is not a backup', () {
      expect(() => WatchBackup.decode('nope'), throwsA(isA<BackupException>()));
      expect(
        () => WatchBackup.decode('{"format":"other"}'),
        throwsA(isA<BackupException>()),
      );
    });

    test('refuses a newer version', () {
      expect(
        () => WatchBackup.decode(
          '{"format":"sentorr-watch-history","version":99,"entries":[]}',
        ),
        throwsA(
          isA<BackupException>().having(
            (e) => e.message,
            'message',
            contains('newer'),
          ),
        ),
      );
    });

    test('skips a bad entry', () {
      final decoded = WatchBackup.decode(
        '{"format":"sentorr-watch-history","version":1,"entries":[1,{}]}',
      );
      expect(decoded.entries, isEmpty);
    });
  });

  group('WatchSnapshot.merge', () {
    test('keeps the newer record of each item, newest first', () {
      final merged =
          _snap([
            _entry(1, const Duration(hours: 5), minutes: 10),
            _entry(2, const Duration(hours: 1)),
          ]).merge(
            _snap([
              _entry(1, const Duration(hours: 2), minutes: 40),
              _entry(3, const Duration(hours: 3)),
            ]),
            capacity: 100,
          );
      expect(merged.entries.map((e) => e.id), ['tt2', 'tt1', 'tt3']);
      expect(merged.entries[1].position, const Duration(minutes: 40));
    });

    test('a removal on either side wins over older progress', () {
      final removal = {'tt1': _now.subtract(const Duration(hours: 1))};
      final merged = _snap([_entry(1, const Duration(hours: 5))])
          .merge(_snap([], removal), capacity: 100);
      expect(merged.entries, isEmpty);
      expect(merged.removals, removal);
    });

    test('watching again after a removal brings the title back', () {
      final merged = _snap([_entry(1, const Duration(minutes: 5))]).merge(
        _snap([], {'tt1': _now.subtract(const Duration(hours: 1))}),
        capacity: 100,
      );
      expect(merged.entries.map((e) => e.id), ['tt1']);
    });

    test('drops the oldest past capacity and forgets old removals', () {
      final merged =
          _snap([for (var i = 1; i <= 5; i++) _entry(i, Duration(hours: i))])
              .merge(
                _snap([], {'tt9': _now.subtract(const Duration(days: 200))}),
                capacity: 3,
              );
      expect(merged.entries.map((e) => e.id), ['tt1', 'tt2', 'tt3']);
      expect(merged.removals, isEmpty);
    });

    test('matches only an identical snapshot', () {
      final a = _snap([_entry(1, const Duration(hours: 1))]);
      expect(a.matches(_snap([...a.entries])), isTrue);
      expect(a.matches(_snap([_entry(1, Duration.zero)])), isFalse);
    });
  });

  group('WatchHistoryNotifier', () {
    test('a removal travels in the snapshot and survives a merge', () async {
      final container = ProviderContainer(
        overrides: watchHistoryOverrides([
          _entry(1, const Duration(hours: 2)),
          _entry(2, const Duration(hours: 3)),
        ]),
      );
      addTearDown(container.dispose);
      final history = container.read(watchHistoryProvider.notifier);
      final backup = history.snapshot;
      await history.remove('tt1');
      expect(history.snapshot.removals.keys, ['tt1']);
      await history.merge(backup);
      expect(container.read(watchHistoryProvider).map((e) => e.id), ['tt2']);
    });

    test('clearing is remembered for every title', () async {
      final container = ProviderContainer(
        overrides: watchHistoryOverrides([
          _entry(1, const Duration(hours: 2)),
          _entry(2, const Duration(hours: 3)),
        ]),
      );
      addTearDown(container.dispose);
      final history = container.read(watchHistoryProvider.notifier);
      final backup = history.snapshot;
      await history.clear();
      await history.merge(backup);
      expect(container.read(watchHistoryProvider), isEmpty);
    });
  });
}
