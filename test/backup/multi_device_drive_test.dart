import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/backup/backup_data.dart';
import 'package:sentorr/backup/notifier.dart';
import 'package:sentorr/lists/models.dart';
import 'package:sentorr/lists/notifier.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/watching/notifier.dart';

import '../support/fake_following.dart';
import '../support/fake_history.dart';
import '../support/fake_imdb.dart';
import '../support/fake_lists.dart';
import '../support/mock_drive.dart';

ProviderContainer device(MockDriveRepository drive) {
  final remote = drive.client();
  final container = ProviderContainer(
    overrides: [
      ...watchHistoryOverrides(),
      ...followedSeriesOverrides(),
      ...watchListsOverrides(),
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      backupRemoteProvider.overrideWithValue(remote),
      driveAuthProvider.overrideWithValue(remote.auth),
    ],
  );
  addTearDown(container.dispose);
  container.read(backupProvider);
  return container;
}

Future<void> sync(ProviderContainer device) async {
  await device.read(backupProvider.notifier).syncNow();
  expect(device.read(backupProvider).error, isNull);
}

Future<void> watch(ProviderContainer device, int id, int minutes) => device
    .read(watchHistoryProvider.notifier)
    .record(
      PlaybackItem(title: fakeTitle(id)),
      position: Duration(minutes: minutes),
      duration: const Duration(minutes: 100),
    );

Future<void> converge(List<ProviderContainer> devices) async {
  for (var round = 0; round < 2; round++) {
    for (final device in devices) {
      await sync(device);
    }
  }
  final expected = devices.first.read(backupDataProvider).current();
  for (final device in devices) {
    expect(device.read(backupDataProvider).current().matches(expected), isTrue);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'four concurrent devices preserve lists and exact watch durations',
    () async {
      final drive = MockDriveRepository();
      final devices = [for (var i = 0; i < 4; i++) device(drive)];
      // All four read the empty Drive folder before publishing distinct state.
      for (var i = 0; i < devices.length; i++) {
        await watch(devices[i], i + 1, 10 + i);
        await devices[i]
            .read(watchListsProvider.notifier)
            .set(fakeTitle(i + 1), WatchStatus.watching);
      }
      drive.synchronizeReads(4);
      await Future.wait(devices.map(sync));
      expect(drive.files, hasLength(4));
      expect(drive.deleted, isEmpty);
      await converge(devices.reversed.toList());
      for (final device in devices) {
        expect(device.read(watchListsProvider), hasLength(4));
        final history = device.read(watchHistoryProvider);
        expect(history, hasLength(4));
        for (var i = 0; i < 4; i++) {
          final entry = history.singleWhere(
            (entry) => entry.id == 'tt${i + 1}',
          );
          expect(entry.position, Duration(minutes: 10 + i));
          expect(entry.duration, const Duration(minutes: 100));
        }
      }
      expect(drive.files, hasLength(1));
      final uploads = drive.uploads;
      await converge(devices);
      expect(drive.uploads, uploads);
    },
  );

  test('offline device cannot resurrect removed lists or history', () async {
    final drive = MockDriveRepository();
    final phone = device(drive),
        desktop = device(drive),
        offline = device(drive);
    await watch(phone, 1, 25);
    await phone
        .read(watchListsProvider.notifier)
        .set(fakeTitle(1), WatchStatus.watching);
    await converge([phone, desktop, offline]);
    await desktop.read(watchListsProvider.notifier).set(fakeTitle(1), null);
    await desktop.read(watchHistoryProvider.notifier).remove('tt1');
    await sync(desktop);
    // The disconnected device continues watching another title.
    await watch(offline, 2, 42);
    await offline
        .read(watchListsProvider.notifier)
        .set(fakeTitle(2), WatchStatus.completed);
    await sync(offline);
    await converge([phone, offline, desktop]);
    for (final device in [phone, desktop, offline]) {
      expect(device.read(watchListsProvider).single.id, 'tt2');
      expect(
        device.read(watchListsProvider).single.status,
        WatchStatus.completed,
      );
      expect(device.read(watchHistoryProvider).single.id, 'tt2');
      expect(
        device.read(watchHistoryProvider).single.position,
        const Duration(minutes: 42),
      );
    }
    // A later deliberate update may move progress backwards (rewatching).
    await watch(phone, 2, 5);
    await sync(phone);
    await converge([desktop, offline, phone]);
    for (final device in [phone, desktop, offline]) {
      expect(
        device.read(watchHistoryProvider).single.position,
        const Duration(minutes: 5),
      );
    }
  });

  test(
    'failed publication retains remote state and retries local edits',
    () async {
      final drive = MockDriveRepository();
      final phone = device(drive), desktop = device(drive);
      await watch(phone, 1, 12);
      await sync(phone);
      final retained = Map<String, String>.of(drive.files);
      await watch(desktop, 2, 33);
      await desktop
          .read(watchListsProvider.notifier)
          .set(fakeTitle(2), WatchStatus.planned);
      drive.failUploads = true;
      await desktop.read(backupProvider.notifier).syncNow();
      expect(desktop.read(backupProvider).error, contains('503'));
      expect(desktop.read(backupProvider).busy, isFalse);
      expect(drive.files, retained);
      expect(drive.deleted, isEmpty);
      drive.failUploads = false;
      await converge([desktop, phone]);
      expect(
        phone.read(watchHistoryProvider).map((entry) => entry.id),
        containsAll(['tt1', 'tt2']),
      );
      expect(phone.read(watchListsProvider).single.status, WatchStatus.planned);
    },
  );
}
