import 'package:test/test.dart';
import 'package:torrent_stream/src/engine/downloaded_ranges.dart';

void main() {
  test('shared boundaries, gaps, stable maps and invalidation', () {
    final map = DownloadedRanges();
    void update(int bytes, {bool checking = false}) => map.update(
      offset: 5,
      length: 40,
      pieceLength: 10,
      verifiedBytes: bytes,
      checking: checking,
      havePiece: (p) => {0, 1, 4}.contains(p),
    );
    update(20);
    expect(map.ranges, [(start: 0, end: 15), (start: 35, end: 40)]);
    final previous = map.ranges;
    update(20);
    expect(identical(previous, map.ranges), isTrue);
    update(40);
    expect(map.ranges, [(start: 0, end: 40)]);
    update(20);
    expect(map.ranges, previous);
    update(20, checking: true);
    expect(map.ranges, isEmpty);
    update(20);
    expect(map.ranges, previous);
  });
  test('large maps bound native checks and converge across ticks', () {
    final map = DownloadedRanges();
    var calls = 0;
    void update() => map.update(
      offset: 0,
      length: 10000,
      pieceLength: 1,
      verifiedBytes: 2,
      checking: false,
      havePiece: (p) {
        calls++;
        return p == 0 || p == 9999;
      },
    );
    update();
    expect(calls, inInclusiveRange(1, DownloadedRanges.budget));
    expect(map.ranges, [(start: 0, end: 1)]);
    for (var n = 0; n < 100 && map.ranges.last.end != 10000; n++) {
      calls = 0;
      update();
      expect(calls, lessThanOrEqualTo(DownloadedRanges.budget));
    }
    expect(map.ranges, [(start: 0, end: 1), (start: 9999, end: 10000)]);
    calls = 0;
    update();
    expect(calls, 0);
  });
  test('slow native checks yield before exhausting the call budget', () {
    final map = DownloadedRanges();
    var calls = 0;
    map.update(
      offset: 0,
      length: 10000,
      pieceLength: 1,
      verifiedBytes: 1,
      checking: false,
      havePiece: (p) {
        calls++;
        final watch = Stopwatch()..start();
        while (watch.elapsedMicroseconds < 500) {}
        return p == 0;
      },
    );
    expect(calls, inInclusiveRange(1, 16));
    expect(map.ranges, [(start: 0, end: 1)]);
  });
  test(
    'bulk map discovers distant pieces immediately with no native probes',
    () {
      final map = DownloadedRanges();
      map.update(
        offset: 0,
        length: 100000,
        pieceLength: 1,
        verifiedBytes: 2,
        checking: false,
        pieces: [for (var n = 0; n < 100000; n++) n == 0 || n == 99999 ? 1 : 0],
        havePiece: (_) =>
            throw StateError('Bulk map must replace individual probes'),
      );
      expect(map.ranges, [(start: 0, end: 1), (start: 99999, end: 100000)]);
    },
  );
}
