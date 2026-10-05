import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/backup/backup_bundle.dart';
import 'package:sentorr/backup/watch_backup.dart';
import 'package:sentorr/following/snapshot.dart';
import 'package:sentorr/watching/models.dart';

import '../support/fake_imdb.dart';

final _at = DateTime.utc(2026, 10, 4, 12);
const _noFollowing = FollowedSnapshot([], {});

void main() {
  group('BackupBundle', () {
    test('round-trips history and followed series', () {
      final bundle = BackupBundle(
        watch: WatchSnapshot([
          WatchEntry(
            title: fakeTitle(1),
            position: const Duration(minutes: 5),
            duration: const Duration(minutes: 90),
            updatedAt: _at,
          ),
        ], {}),
        following: _noFollowing,
      );
      final back = BackupBundle.decode(bundle.encode());
      expect(back.watch.entries.single.id, 'tt1');
      expect(back.following.series, isEmpty);
    });

    test('still reads a history-only file', () {
      final old = WatchBackup.encode(const WatchSnapshot([], {}));
      expect(BackupBundle.decode(old).watch.entries, isEmpty);
    });

    test('refuses a newer version', () {
      expect(
        () => BackupBundle.decode('{"format":"sentorr-backup","version":9}'),
        throwsA(isA<BackupException>()),
      );
    });
  });
}
