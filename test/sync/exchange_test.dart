import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/backup/watch_backup.dart';
import 'package:sentorr/following/snapshot.dart';
import 'package:sentorr/sync/exchange.dart';
import 'package:sentorr/sync/payload.dart';

Map<String, dynamic> exchange() => {
  ...const SyncPayload(
    watch: WatchSnapshot([], {}),
    following: FollowedSnapshot([], {}),
  ).toJson(),
  'library': const PeerLibrary().toJson(),
};

void main() {
  test('validates the whole exchange before applying records', () {
    expect(SyncExchange.decode(exchange()).library.media, isEmpty);
    for (final key in ['watch', 'following', 'lists', 'library']) {
      expect(
        () => SyncExchange.decode(exchange()..remove(key)),
        throwsFormatException,
        reason: key,
      );
    }
    expect(
      () => SyncExchange.decode(
        exchange()..['library'] = {'revision': 'r', 'media': []},
      ),
      throwsFormatException,
    );
    expect(
      () => SyncExchange.decode(exchange()..['following'] = {'series': []}),
      throwsFormatException,
    );
    expect(
      () => SyncExchange.decode(exchange()..['lists'] = {'entries': 'bad'}),
      throwsFormatException,
    );
  });
}
