import 'dart:async';

import 'package:test/test.dart';
import 'package:torrent_stream/src/engine/core.dart';
import 'package:torrent_stream/src/engine/snapshot_equality.dart';
import 'package:torrent_stream/torrent_stream.dart';

void main() {
  test('snapshot comparisons preserve every transfer and ownership change', () {
    const base = TorrentSnapshot(
      infoHash: 'a',
      savePath: '/a',
      storage: TorrentStorage.kept,
    );
    const file = TorrentStreamFile(
      index: 0,
      path: 'a',
      length: 10,
      isPadFile: false,
    );
    const changes = [
      TorrentSnapshot(
        infoHash: 'b',
        savePath: '/a',
        storage: TorrentStorage.kept,
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/b',
        storage: TorrentStorage.kept,
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.cached,
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        owners: {'owner'},
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        pausedOwners: {'owner'},
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        paused: true,
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        transferState: TorrentTransferState.seeding,
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        downloadBytesPerSecond: 1,
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        uploadBytesPerSecond: 1,
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        receivedBytes: 1,
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        uploadedBytes: 1,
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        verifiedBytes: 1,
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        peers: 1,
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        seeds: 1,
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        knownPeers: 1,
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        connections: 1,
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        connectionCandidates: 1,
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        error: 'disk full',
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        fileBytes: [1],
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        wanted: {0},
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        files: [file],
      ),
      TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        streams: [StreamSnapshot(id: 1, owner: 'stream', file: file)],
      ),
    ];
    expect(
      sameSnapshot(
        base,
        const TorrentSnapshot(
          infoHash: 'a',
          savePath: '/a',
          storage: TorrentStorage.kept,
        ),
      ),
      isTrue,
    );
    for (final changed in changes) {
      expect(sameSnapshot(base, changed), isFalse);
      expect(sameSnapshot(changed, base), isFalse);
    }
  });

  test(
    'stream traffic changes are published even when torrent progress is unchanged',
    () {
      const file = TorrentStreamFile(
        index: 0,
        path: 'a',
        length: 10,
        isPadFile: false,
      );
      TorrentSnapshot snapshot(StreamSnapshot stream) => TorrentSnapshot(
        infoHash: 'a',
        savePath: '/a',
        storage: TorrentStorage.kept,
        streams: [stream],
      );
      final base = snapshot(
        const StreamSnapshot(id: 1, owner: 's', file: file),
      );
      for (final stream in const [
        StreamSnapshot(id: 1, owner: 's', file: file, cachedBytes: 1),
        StreamSnapshot(id: 1, owner: 's', file: file, servedBytes: 1),
        StreamSnapshot(id: 1, owner: 's', file: file, requests: 1),
        StreamSnapshot(id: 1, owner: 's', file: file, indexStatus: 'ready'),
        StreamSnapshot(id: 1, owner: 's', file: file, mediaDuration: 10),
        StreamSnapshot(
          id: 1,
          owner: 's',
          file: file,
          downloadedTimes: [(start: 1, end: 2)],
        ),
        StreamSnapshot(
          id: 1,
          owner: 's',
          file: file,
          downloadedRanges: [(start: 5, end: 10)],
        ),
        StreamSnapshot(id: 2, owner: 's', file: file),
        StreamSnapshot(id: 1, owner: 'other', file: file),
      ]) {
        expect(sameSnapshot(base, snapshot(stream)), isFalse);
      }
    },
  );

  test(
    'an idle engine sends its initial state once instead of every poll',
    () async {
      final states = <Map<String, Object?>>[];
      final core = EngineCore(
        const TorrentEngineSettings(
          enableDht: false,
          enableLsd: false,
          enableUpnp: false,
          enableNatPmp: false,
          listenInterfaces: '127.0.0.1:0',
        ),
        states.add,
      );
      try {
        for (var i = 0; i < 100; i++) {
          core.publish();
        }
        await Future<void>.delayed(const Duration(milliseconds: 550));
        expect(states, hasLength(1));
        expect(states.single['value'], isEmpty);
      } finally {
        await core.close();
      }
    },
  );
}
