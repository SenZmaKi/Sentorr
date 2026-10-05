import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/following/repository.dart';
import 'package:sentorr/shared/persistence/json_file_store.dart';
import 'package:sentorr/watching/repository.dart';

void main() {
  test(
    'empty repositories retain logical clock and removal revisions on disk',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sentorr_state_clock',
      );
      addTearDown(() => directory.delete(recursive: true));
      final watchStore = JsonFileStore(File('${directory.path}/watch.json'));
      final followStore = JsonFileStore(File('${directory.path}/follow.json'));
      final at = DateTime.now();
      final watch = WatchHistoryRepository(watchStore)
        ..clock = 200
        ..removals = {'tt1': at}
        ..removalRevisions = {'tt1': 199};
      final following = FollowedSeriesRepository(followStore)
        ..clock = 300
        ..removals = {'tt2': at}
        ..removalRevisions = {'tt2': 299};
      await watch.save([]);
      await following.save([]);
      final restoredWatch = WatchHistoryRepository(watchStore);
      final restoredFollow = FollowedSeriesRepository(followStore);
      expect(await restoredWatch.load(), isEmpty);
      expect(await restoredFollow.load(), isEmpty);
      expect(restoredWatch.clock, 200);
      expect(restoredFollow.clock, 300);
      expect(restoredWatch.removalRevisions, {'tt1': 199});
      expect(restoredFollow.removalRevisions, {'tt2': 299});
      restoredWatch.removals.clear();
      restoredWatch.removalRevisions.clear();
      restoredFollow.removals.clear();
      restoredFollow.removalRevisions.clear();
      await restoredWatch.save([]);
      await restoredFollow.save([]);
      final emptyWatch = WatchHistoryRepository(watchStore);
      final emptyFollow = FollowedSeriesRepository(followStore);
      await emptyWatch.load();
      await emptyFollow.load();
      expect(emptyWatch.clock, 200);
      expect(emptyFollow.clock, 300);
    },
  );
}
