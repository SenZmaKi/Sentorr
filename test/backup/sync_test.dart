import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/app/services.dart';
import 'package:sentorr/backup/backup_bundle.dart';
import 'package:sentorr/backup/drive/drive_auth.dart';
import 'package:sentorr/backup/notifier.dart';
import 'package:sentorr/backup/remote.dart';
import 'package:sentorr/following/models.dart';
import 'package:sentorr/following/notifier.dart';
import 'package:sentorr/settings/models.dart';
import 'package:sentorr/watching/models.dart';
import 'package:sentorr/watching/notifier.dart';

import '../support/fake_following.dart';
import '../support/fake_history.dart';
import '../support/fake_imdb.dart';

/// One shared file, versioned like Drive's checksum.
class _Remote implements BackupRemote {
  String? _content;
  int revision = 0;
  int uploads = 0;

  /// Runs once after the next download, as if another device synced then.
  Future<void> Function()? afterDownload;

  @override
  Future<RemoteBackup?> download() async {
    final content = _content;
    final result = content == null
        ? null
        : RemoteBackup(BackupBundle.decode(content), '$revision');
    final hook = afterDownload;
    afterDownload = null;
    await hook?.call();
    return result;
  }

  @override
  Future<void> upload(BackupBundle bundle, {required String? basedOn}) async {
    if ((_content == null ? null : '$revision') != basedOn) {
      throw const BackupConflict();
    }
    _content = bundle.encode();
    revision++;
    uploads++;
  }
}

class _SignedIn extends DriveAuth {
  _SignedIn() : super(dio: Dio(), openBrowser: (_) async => true);

  @override
  bool get connected => true;
}

final _now = DateTime.now();

WatchEntry _watched(int n, Duration ago) => WatchEntry(
  title: fakeTitle(n),
  position: const Duration(minutes: 10),
  duration: const Duration(minutes: 90),
  updatedAt: _now.subtract(ago),
);

/// An app with the given history and preferences, signed in to [remote].
ProviderContainer _device(
  _Remote remote, {
  List<WatchEntry> history = const [],
  List<FollowedSeries> followed = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      ...watchHistoryOverrides(history),
      ...followedSeriesOverrides(followed),
      initialSettingsProvider.overrideWithValue(const AppSettings()),
      backupRemoteProvider.overrideWithValue(remote),
      driveAuthProvider.overrideWithValue(_SignedIn()),
    ],
  );
  addTearDown(container.dispose);
  container.read(backupProvider.notifier);
  return container;
}

Future<void> _sync(ProviderContainer device) =>
    device.read(backupProvider.notifier).syncNow();

List<String> _ids(ProviderContainer d) => [
  for (final e in d.read(watchHistoryProvider)) e.id,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('devices that sync in turn end up with the same history', () async {
    final remote = _Remote();
    final phone = _device(
      remote,
      history: [_watched(1, const Duration(hours: 3))],
    );
    final pc = _device(
      remote,
      history: [_watched(2, const Duration(hours: 2))],
    );
    await _sync(phone);
    await _sync(pc);
    await _sync(phone);
    expect(_ids(phone), ['tt2', 'tt1']);
    expect(_ids(pc), ['tt2', 'tt1']);
  });

  test('the newer progress on either device wins', () async {
    final remote = _Remote();
    final phone = _device(
      remote,
      history: [_watched(1, const Duration(hours: 5))],
    );
    final pc = _device(
      remote,
      history: [_watched(1, const Duration(hours: 1))],
    );
    await _sync(phone);
    await _sync(pc);
    await _sync(phone);
    for (final d in [phone, pc]) {
      expect(
        d.read(watchHistoryProvider).single.updatedAt,
        _now.subtract(const Duration(hours: 1)),
      );
    }
  });

  test('a removal on one device reaches the other', () async {
    final remote = _Remote();
    final entries = [_watched(1, const Duration(hours: 3))];
    final phone = _device(remote, history: entries);
    final pc = _device(remote, history: entries);
    await _sync(phone);
    await _sync(pc);
    await phone.read(watchHistoryProvider.notifier).remove('tt1');
    await _sync(phone);
    await _sync(pc);
    expect(_ids(pc), isEmpty);
  });

  test(
    'a device that lost the race merges the winner and tries again',
    () async {
      final remote = _Remote();
      final phone = _device(
        remote,
        history: [_watched(1, const Duration(hours: 3))],
      );
      final pc = _device(
        remote,
        history: [_watched(2, const Duration(hours: 2))],
      );
      await _sync(phone);
      // The phone replaces the backup while the PC is between reading and
      // writing it.
      remote.afterDownload = () async {
        await phone
            .read(watchHistoryProvider.notifier)
            .record(
              (_watched(3, Duration.zero)).item,
              position: const Duration(minutes: 20),
              duration: const Duration(minutes: 90),
            );
        await _sync(phone);
      };
      await _sync(pc);
      expect(pc.read(backupProvider).error, isNull);
      expect(_ids(pc), containsAll(['tt1', 'tt2', 'tt3']));
      await _sync(phone);
      expect(_ids(phone), containsAll(['tt1', 'tt2', 'tt3']));
    },
  );

  test('devices in step stop rewriting the backup', () async {
    final remote = _Remote();
    final phone = _device(
      remote,
      history: [_watched(1, const Duration(hours: 3))],
    );
    final pc = _device(remote);
    await _sync(phone);
    await _sync(pc);
    await _sync(phone);
    final uploads = remote.uploads;
    await _sync(pc);
    await _sync(phone);
    expect(remote.uploads, uploads);
  });

  test(
    'followed series follow, each device keeping its own auto-download',
    () async {
      final remote = _Remote();
      final series = fakeTitle(2, series: true);
      final phone = _device(
        remote,
        followed: [following(series, episode: 3, watchedAt: _now)],
      );
      final pc = _device(remote);
      await _sync(phone);
      await _sync(pc);
      expect(pc.read(followedSeriesProvider).map((s) => s.id), [series.id]);
      final uploads = remote.uploads;
      await pc
          .read(followedSeriesProvider.notifier)
          .setAutoDownload(series.id, true);
      await _sync(pc);
      await _sync(phone);
      expect(remote.uploads, uploads);
      expect(phone.read(followedSeriesProvider).single.autoDownload, isNull);
    },
  );

  test('any number of devices converge, whatever order they sync in', () async {
    final remote = _Remote();
    final devices = [
      for (var i = 0; i < 4; i++)
        _device(
          remote,
          history: [_watched(i + 1, Duration(hours: i + 1))],
          followed: [
            following(
              fakeTitle(10 + i, series: true),
              episode: i + 1,
              watchedAt: _now.subtract(Duration(hours: i)),
            ),
          ],
        ),
    ];
    // One device drops a title the others also hold, and syncs first.
    await devices[0].read(watchHistoryProvider.notifier).remove('tt2');
    final random = Random(7);
    for (var round = 0; round < 3; round++) {
      for (final i in [0, 1, 2, 3]..shuffle(random)) {
        await _sync(devices[i]);
      }
    }
    // A last pass lets the final uploader's work reach everyone.
    for (final d in devices) {
      await _sync(d);
    }
    final histories = [for (final d in devices) _ids(d).toSet()];
    final followed = [
      for (final d in devices)
        d.read(followedSeriesProvider).map((s) => s.id).toSet(),
    ];
    for (final h in histories) {
      expect(h, histories.first);
    }
    for (final f in followed) {
      expect(f, followed.first);
      expect(f, hasLength(4));
    }
    expect(histories.first, {'tt1', 'tt3', 'tt4'});
    final uploads = remote.uploads;
    for (final d in devices) {
      await _sync(d);
    }
    expect(remote.uploads, uploads);
  });
}
