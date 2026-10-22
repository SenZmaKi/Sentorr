import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentorr/backup/backup_bundle.dart';
import 'package:sentorr/backup/backup_data.dart';
import 'package:sentorr/backup/watch_backup.dart';
import 'package:sentorr/following/notifier.dart';
import 'package:sentorr/following/repository.dart';
import 'package:sentorr/following/snapshot.dart';
import 'package:sentorr/lists/models.dart';
import 'package:sentorr/lists/notifier.dart';
import 'package:sentorr/lists/repository.dart';
import 'package:sentorr/lists/snapshot.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/watching/models.dart';
import 'package:sentorr/watching/notifier.dart';
import 'package:sentorr/watching/repository.dart';

import '../support/fake_imdb.dart';
import '../support/fake_following.dart';

class _FailOnce extends JsonFileStore {
  _FailOnce(super.file);
  bool fail = true;
  int attempts = 0;
  @override
  Future<void> replace(String contents) async {
    attempts++;
    if (fail) {
      fail = false;
      throw FileSystemException('injected temporary write failure', file.path);
    }
    await super.replace(contents);
  }
}

void main() {
  for (final domain in ['watch', 'following', 'lists']) {
    test('retry persists previously failed $domain restore', () async {
      final dir = await Directory.systemTemp.createTemp(
        'sentorr-restore-retry-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final failing = _FailOnce(File('${dir.path}/$domain.json'));
      JsonFileStore store(String name) => name == domain
          ? failing
          : JsonFileStore(File('${dir.path}/$name.json'));
      final watch = WatchHistoryRepository(store('watch'));
      final followed = FollowedSeriesRepository(store('following'));
      final lists = WatchListsRepository(store('lists'));
      final device = ProviderContainer(
        overrides: [
          watchHistoryRepositoryProvider.overrideWithValue(watch),
          initialWatchHistoryProvider.overrideWithValue([]),
          followedSeriesRepositoryProvider.overrideWithValue(followed),
          initialFollowedSeriesProvider.overrideWithValue([]),
          watchListsRepositoryProvider.overrideWithValue(lists),
          initialWatchListsProvider.overrideWithValue([]),
        ],
      );
      addTearDown(device.dispose);
      final bundle = BackupBundle(
        watch: WatchSnapshot([
          WatchEntry(
            title: fakeTitle(1),
            position: const Duration(minutes: 5),
            duration: const Duration(minutes: 90),
            updatedAt: DateTime.now(),
          ),
        ], {}),
        following: FollowedSnapshot([
          following(fakeTitle(2, series: true), episode: 1),
        ], {}),
        lists: ListsSnapshot([
          ListEntry(
            title: fakeTitle(3),
            status: WatchStatus.planned,
            updatedAt: DateTime.now(),
          ),
        ]),
      );
      final data = device.read(backupDataProvider);
      await expectLater(
        data.apply(bundle),
        throwsA(isA<FileSystemException>()),
      );
      expect(device.read(watchHistoryProvider), hasLength(1));
      await data.apply(bundle);
      expect(device.read(watchListsProvider), hasLength(1));
      expect(failing.attempts, 2);
      expect(
        await WatchHistoryRepository(JsonFileStore(watch.store.file)).load(),
        hasLength(1),
      );
      expect(
        await FollowedSeriesRepository(JsonFileStore(followed.store.file))
            .load(),
        hasLength(1),
      );
      expect(
        await WatchListsRepository(JsonFileStore(lists.store.file)).load(),
        hasLength(1),
      );
    });
  }
}
