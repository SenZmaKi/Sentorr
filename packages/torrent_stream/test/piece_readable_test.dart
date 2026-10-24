import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:test/test.dart';
import 'package:torrent_stream/src/engine/native_session.dart';

import 'read_support.dart';

class WriteHandle extends TestHandle {
  bool verified = false;
  List<PartialPieceInfo> queue = [];
  @override
  bool havePiece(int piece) => verified;
  @override
  List<PartialPieceInfo> getDownloadQueue() => queue;
}

void main() {
  test(
    'hash verification alone does not allow reads while writes are pending',
    () {
      final handle = WriteHandle();
      expect(pieceReadable(handle, 0), isFalse);
      handle.verified = true;
      handle.queue = [
        const PartialPieceInfo(
          pieceIndex: 0,
          blocksInPiece: 2,
          finished: 1,
          writing: 1,
          requested: 0,
        ),
      ];
      expect(pieceReadable(handle, 0), isFalse);
      handle.queue = [
        const PartialPieceInfo(
          pieceIndex: 0,
          blocksInPiece: 2,
          finished: 2,
          writing: 0,
          requested: 0,
        ),
      ];
      expect(pieceReadable(handle, 0), isTrue);
      handle.queue = [];
      expect(pieceReadable(handle, 0), isTrue);
    },
  );
}
