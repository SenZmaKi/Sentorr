import 'package:libtorrent_dart/libtorrent_dart.dart';

class TestHandle implements TorrentHandle {
  TestHandle({this.pieceLength = 16, this.lastPieceSize});
  @override
  final int pieceLength;
  final int? lastPieceSize;
  final priorities = <int, int>{};
  final deadlines = <int, int>{};
  int calls = 0;

  @override
  int pieceSize(int piece) =>
      piece == 2 ? lastPieceSize ?? pieceLength : pieceLength;
  @override
  void setPiecePriority(int pieceIndex, int priority) {
    calls++;
    priorities[pieceIndex] = priority;
  }

  @override
  void setPieceDeadline(int pieceIndex, int deadline, {int flags = 0}) {
    calls++;
    deadlines[pieceIndex] = deadline;
  }

  @override
  void resetPieceDeadline(int pieceIndex) {
    calls++;
    deadlines.remove(pieceIndex);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
