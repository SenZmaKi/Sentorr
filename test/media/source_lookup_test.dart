import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/media/source_lookup.dart';
import 'package:sentorr/torrents/models.dart';
import 'package:sentorr/torrents/resolution_models.dart';

TorrentResolution get _resolution => TorrentResolution(
  query: TorrentQuery(title: 'Movie'),
  candidates: const [],
  failures: const [],
);

void main() {
  test('discovery overlaps but a fast torrent result cannot bypass local or peer data', () async {
    final local = Completer<String?>();
    final peer = Completer<String?>();
    final search = Completer<TorrentResolution>();
    final started = <String>[];
    final lookup = SourceLookup<String, String>(
      local: () {
        started.add('local');
        return local.future;
      },
      peer: () {
        started.add('peer');
        return peer.future;
      },
      search: (_) {
        started.add('torrent');
        return search.future;
      },
    );
    expect(started, ['local', 'peer', 'torrent']);
    var chosen = '';
    final choosing = () async {
      chosen =
          await lookup.local ??
          await lookup.peer ??
          (await lookup.torrents).query.title;
    }();
    search.complete(_resolution);
    peer.complete('Laptop');
    await Future<void>.delayed(Duration.zero);
    expect(chosen, isEmpty);
    local.complete('Cache');
    await choosing;
    expect(chosen, 'Cache');
    lookup.close();
  });

  test('a speculative search error does not prevent a local hit', () async {
    final lookup = SourceLookup<String, String>(
      local: () async => 'Cache',
      peer: () async => null,
      search: (_) => Future.error(StateError('Search unavailable')),
    );
    expect(await lookup.local, 'Cache');
    await Future<void>.delayed(Duration.zero);
    lookup.close();
  });

  test(
    'cancelling releases waits and cancels the speculative torrent search',
    () async {
      final cancel = CancelToken();
      late CancelToken searchToken;
      var closed = 0;
      final lookup = SourceLookup<String, String>(
        local: () => Completer<String?>().future,
        peer: () => Completer<String?>().future,
        search: (token) {
          searchToken = token;
          return Completer<TorrentResolution>().future;
        },
        cancel: cancel,
        onClose: () => closed++,
      );
      final waiting = expectLater(lookup.local, throwsA(isA<DioException>()));
      cancel.cancel();
      await waiting;
      expect(searchToken.isCancelled, true);
      lookup.close();
      expect(closed, 1);
    },
  );
}
