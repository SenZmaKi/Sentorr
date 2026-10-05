import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:test/test.dart';
import 'package:torrent_stream/src/engine/core.dart';
import 'package:torrent_stream/src/engine/tracker_policy.dart';
import 'package:torrent_stream/torrent_stream.dart';

void main() {
  test('private flag is read from info, not a binary field or root', () {
    bool check(String value) =>
        isPrivateTorrent(Uint8List.fromList(ascii.encode(value)));
    expect(check('d4:infod4:name1:xee'), false);
    expect(check('d4:infod7:privatei1eee'), true);
    expect(check('d4:infod7:privatei0eee'), false);
    expect(check('d4:infod6:pieces12:7:privatei1eee'), false);
    expect(check('d4:infode7:privatei1ee'), false);
    expect(check('d4:infod7:private'), true);
  });

  for (final private in [false, true]) {
    test(
      'engine preserves provider trackers; defaults private=$private',
      () async {
        final root = await Directory.systemTemp.createTemp('tracker-policy-');
        final film = await File(
          '${root.path}/film.mkv',
        ).writeAsBytes([1, 2, 3]);
        const provider = 'http://127.0.0.1:1/provider';
        const fallback = 'http://127.0.0.1:1/default';
        var bytes = createTorrentData(
          sourcePath: film.path,
          trackerUrl: provider,
        );
        if (private) {
          final at = latin1.decode(bytes).indexOf('12:piece layers') - 1;
          bytes = Uint8List.fromList([
            ...bytes.take(at),
            ...ascii.encode('7:privatei1e'),
            ...bytes.skip(at),
          ]);
        }
        expect(isPrivateTorrent(bytes), private);
        final core = EngineCore(
          const TorrentEngineSettings(
            enableDht: false,
            enableLsd: false,
            enableUpnp: false,
            enableNatPmp: false,
            listenInterfaces: '127.0.0.1:0',
            defaultTrackers: [fallback, provider, fallback],
          ),
          (_) {},
        );
        try {
          final hash = await core.add(
            {'kind': 'bytes', 'value': bytes},
            owner: 'first',
            directory: '${root.path}/download',
            storage: TorrentStorage.kept,
            peers: [],
          );
          List<String> trackers() =>
              core.native.session.findTorrent(hash).getTrackers();
          expect(
            trackers(),
            unorderedEquals([provider, if (!private) fallback]),
          );
          await core.add(
            {'kind': 'magnet', 'value': 'magnet:?xt=urn:btih:$hash'},
            owner: 'second',
            directory: '${root.path}/download',
            storage: TorrentStorage.kept,
            peers: [],
          );
          expect(
            trackers(),
            unorderedEquals([provider, if (!private) fallback]),
          );
        } finally {
          await core.close();
          await root.delete(recursive: true);
        }
      },
    );
  }
}
