import 'dart:async';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:test/test.dart';
import 'package:torrent_stream/src/engine/metadata_hash_cache.dart';
import 'package:torrent_stream/src/engine/torrent_entry.dart';
import 'package:torrent_stream/torrent_stream.dart';

class PriorityHandle implements TorrentHandle {
  var updates = 0;
  List<int> priorities = [];
  @override
  int get numPieces => 4;
  @override
  int get pieceLength => 16;
  @override
  List<TorrentFileEntry> getFiles() => const [
    TorrentFileEntry(index: 0, size: 32, offset: 0, flags: 0, path: 'a'),
    TorrentFileEntry(index: 1, size: 32, offset: 32, flags: 0, path: 'b'),
  ];
  @override
  void prioritizeFiles(List<int> values) {
    updates++;
    priorities = List.of(values);
  }

  @override
  List<int> getFilePriorities() => priorities;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'priority bursts share one operation and unchanged selections do no native work',
    () async {
      final handle = PriorityHandle();
      final entry = TorrentEntry(
        infoHash: 'a',
        handle: handle,
        savePath: '/a',
        storage: TorrentStorage.kept,
      );
      final owner = entry.owners['download'] = TorrentOwner();
      Future<void> until(bool Function() ready) async =>
          expect(ready(), isTrue);
      await entry.prepare(until);
      expect(handle.updates, 1);
      owner.wanted.add(0);
      final first = entry.applyWanted(until);
      for (var i = 0; i < 100; i++) {
        expect(identical(entry.applyWanted(until), first), isTrue);
      }
      await first;
      expect(handle.updates, 2);
      expect(handle.priorities, [4, 0]);
      await entry.applyWanted(until);
      expect(handle.updates, 2);
    },
  );

  test(
    'changes during native acknowledgement are drained before completion',
    () async {
      final handle = PriorityHandle();
      final entry = TorrentEntry(
        infoHash: 'a',
        handle: handle,
        savePath: '/a',
        storage: TorrentStorage.kept,
      );
      final owner = entry.owners['download'] = TorrentOwner();
      Completer<void>? gate;
      Future<void> until(bool Function() ready) async {
        expect(ready(), isTrue);
        await gate?.future;
      }

      await entry.prepare(until);
      gate = Completer<void>();
      owner.wanted.add(0);
      final operation = entry.applyWanted(until);
      await Future<void>.delayed(Duration.zero);
      owner.wanted
        ..clear()
        ..add(1);
      expect(identical(entry.applyWanted(until), operation), isTrue);
      gate.complete();
      await operation;
      expect(handle.priorities, [0, 4]);
      expect(handle.updates, 3);
      owner.paused = true;
      await entry.applyWanted(until);
      expect(handle.priorities, [0, 0]);
    },
  );

  test(
    'metadata cache coalesces equal bytes and isolates mutable keys',
    () async {
      var parses = 0;
      final gate = Completer<String>();
      final cache = MetadataHashCache((_) {
        parses++;
        return gate.future;
      });
      final input = Uint8List.fromList([1, 2, 3]);
      final first = cache.hash(input);
      expect(identical(cache.hash(Uint8List.fromList(input)), first), isTrue);
      input[0] = 9;
      expect(
        identical(cache.hash(Uint8List.fromList([1, 2, 3])), first),
        isTrue,
      );
      gate.complete('hash');
      expect(await first, 'hash');
      expect(parses, 1);
      await cache.hash(input);
      expect(parses, 2);
    },
  );

  test(
    'metadata cache evicts by byte budget and retries failed parses',
    () async {
      var parses = 0;
      final cache = MetadataHashCache((bytes) async {
        parses++;
        if (bytes[0] == 0) throw StateError('bad torrent');
        return '${bytes[0]}';
      }, maxBytes: 3);
      await cache.hash(Uint8List.fromList([1, 1]));
      await cache.hash(Uint8List.fromList([2, 2]));
      await cache.hash(Uint8List.fromList([1, 1]));
      expect(parses, 3);
      for (var i = 0; i < 2; i++) {
        await expectLater(
          cache.hash(Uint8List.fromList([0])),
          throwsStateError,
        );
      }
      expect(parses, 5);
    },
  );
}
