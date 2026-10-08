import 'dart:convert';

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

    test(
      'legacy bundles remain readable and new bundles declare shared formats',
      () {
        final json = jsonDecode(
          const BackupBundle(
            watch: WatchSnapshot([], {}),
            following: _noFollowing,
          ).encode(),
        ) as Map<String, dynamic>;
        expect(json['version'], 3);
        expect(json['formats'], {'watch': 2, 'following': 1, 'lists': 1});
        for (final version in [1, 2]) {
          final legacy = {...json, 'version': version}
            ..remove('formats')
            ..remove('lists');
          expect(
            BackupBundle.decode(jsonEncode(legacy), strict: true).watch.entries,
            isEmpty,
          );
        }
      },
    );

    test('new bundles refuse missing or unsupported format declarations', () {
      final json = jsonDecode(
        const BackupBundle(
          watch: WatchSnapshot([], {}),
          following: _noFollowing,
        ).encode(),
      ) as Map<String, dynamic>;
      for (final formats in [
        {'watch': 2, 'following': 1, 'lists': 1, 'unknown': 1},
        null,
        {},
        {'watch': 99, 'following': 1, 'lists': 1},
        {'watch': 2, 'following': 99, 'lists': 1},
        {'watch': 2, 'following': 1, 'lists': 99},
      ]) {
        expect(
          () => BackupBundle.decode(jsonEncode({...json, 'formats': formats})),
          throwsA(isA<BackupException>()),
        );
      }
      for (final key in ['watch', 'following', 'lists']) {
        expect(
          () => BackupBundle.decode(jsonEncode({...json}..remove(key))),
          throwsA(isA<BackupException>()),
        );
      }
    });

    test(
      'Drive rejects invalid records rather than silently dropping them',
      () {
        final json = jsonDecode(
          const BackupBundle(
            watch: WatchSnapshot([], {}),
            following: _noFollowing,
          ).encode(),
        ) as Map<String, dynamic>;
        final badWatch = {
          ...json,
          'watch': {
            'entries': [{}],
            'removed': [],
          },
        };
        expect(
          BackupBundle.decode(jsonEncode(badWatch)).watch.entries,
          isEmpty,
        );
        expect(
          () => BackupBundle.decode(jsonEncode(badWatch), strict: true),
          throwsA(isA<BackupException>()),
        );
        final badRemoval = {
          ...json,
          'watch': {
            'entries': [],
            'removed': [
              {'key': 'tt1', 'at': 'bad'},
            ],
          },
        };
        expect(
          () => BackupBundle.decode(jsonEncode(badRemoval), strict: true),
          throwsA(isA<BackupException>()),
        );
      },
    );

    test('refuses a newer version', () {
      expect(
        () => BackupBundle.decode('{"format":"sentorr-backup","version":9}'),
        throwsA(isA<BackupException>()),
      );
    });
  });
}
