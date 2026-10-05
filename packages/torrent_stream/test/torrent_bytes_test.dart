import 'dart:async';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:test/test.dart';
import 'package:torrent_stream/src/engine/cancellation.dart';
import 'package:torrent_stream/src/engine/piece_scheduler.dart';
import 'package:torrent_stream/src/engine/torrent_bytes.dart';

import 'read_support.dart';

void main() {
  final pieces = [
    for (var piece = 0; piece < 3; piece++)
      Uint8List.fromList(
        List.generate(piece == 2 ? 7 : 16, (i) => piece * 16 + i),
      ),
  ];
  late TorrentBytes bytes;
  late TestHandle handle;
  var loads = 0;
  setUp(() {
    loads = 0;
    handle = TestHandle(lastPieceSize: 7);
    bytes = TorrentBytes(
      handle,
      const TorrentFileEntry(
        index: 0,
        offset: 3,
        size: 36,
        flags: 0,
        path: 'video.mkv',
      ),
      (piece, _) async {
        loads++;
        return pieces[piece];
      },
      PieceScheduler(handle),
      maxCacheBytes: 16,
    );
  });
  tearDown(() => bytes.close());

  test(
    'single-piece reads borrow immutable bytes and remain valid after eviction',
    () async {
      final owner = Cancellation();
      final slice = await bytes.read(2, 5, owner);
      expect(slice, [5, 6, 7, 8, 9]);
      pieces[0][5] = 101;
      expect(slice[0], 101); // Shares storage rather than copying bytes.
      pieces[0][5] = 5;
      expect(() => slice[0] = 99, throwsUnsupportedError);
      await bytes.read(13, 4, owner); // evicts the first piece
      expect(slice, [5, 6, 7, 8, 9]);
      expect(bytes.cachedBytes, 16);
    },
  );

  test(
    'cross-piece and short final-piece reads retain exact file offsets',
    () async {
      final owner = Cancellation();
      expect(await bytes.read(10, 8, owner), List.generate(8, (i) => 13 + i));
      expect(await bytes.read(28, 8, owner), List.generate(8, (i) => 31 + i));
      expect(await bytes.read(36, 0, owner), isEmpty);
    },
  );

  test('same-piece chunks reuse one loaded piece', () async {
    final owner = Cancellation();
    await bytes.read(0, 4, owner);
    await bytes.read(4, 4, owner);
    expect(loads, 1);
  });

  test('cancellation and invalid ranges still reject reads', () async {
    final owner = Cancellation()..cancel();
    await expectLater(bytes.read(0, 4, owner), throwsA(isA<ReadCancelled>()));
    await expectLater(bytes.read(35, 2, Cancellation()), throwsRangeError);
  });

  test('cancelling a pending read returns no borrowed bytes', () async {
    final gate = Completer<Uint8List>();
    bytes.close();
    bytes = TorrentBytes(
      handle,
      const TorrentFileEntry(
        index: 0,
        offset: 0,
        size: 16,
        flags: 0,
        path: 'video.mkv',
      ),
      (_, _) => gate.future,
      PieceScheduler(handle),
    );
    final owner = Cancellation();
    final pending = bytes.read(0, 4, owner);
    final rejected = expectLater(pending, throwsA(isA<ReadCancelled>()));
    owner.cancel();
    gate.complete(pieces[0]);
    await rejected;
    bytes.release(owner);
  });
}
