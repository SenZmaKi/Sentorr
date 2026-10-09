import 'dart:math' as math;
import 'dart:typed_data';

import '../models.dart';

/// Availability projection in the worker, never in the paint path. Bulk native
/// snapshots update all pieces together. Older binaries fall back to bounded
/// sampling; unknown pieces stay empty until checked.
class DownloadedRanges {
  static const budget = 2048;
  Uint8List _pieces = Uint8List(0);
  int _cursor = 0, _verified = -1, _remaining = 0;
  List<DownloadedRange> ranges = const [];

  void update({
    required int offset,
    required int length,
    required int pieceLength,
    required int verifiedBytes,
    required bool checking,
    required bool Function(int) havePiece,
    List<int>? pieces,
  }) {
    if (length <= 0 || pieceLength <= 0) return;
    final first = offset ~/ pieceLength;
    final count = (offset + length - 1) ~/ pieceLength - first + 1;
    if (checking || verifiedBytes < _verified || _pieces.length != count) {
      _pieces = Uint8List(count);
      ranges = const [];
      _cursor = 0;
      _remaining = count;
    }
    if (_verified != verifiedBytes || checking) _remaining = count;
    _verified = verifiedBytes;
    if (checking) return;
    if (verifiedBytes == length) {
      if (ranges.length != 1 || ranges.single != (start: 0, end: length)) {
        ranges = [(start: 0, end: length)];
      }
      return;
    }
    if (verifiedBytes == 0) return;
    if (pieces != null && pieces.length >= first + count) {
      var changed = false;
      for (var n = 0; n < count; n++) {
        final value = pieces[first + n];
        if (_pieces[n] != value) {
          _pieces[n] = value;
          changed = true;
        }
      }
      _remaining = 0;
      if (changed) _merge(first, count, offset, length, pieceLength);
      return;
    }
    var changed = false;
    var checked = 0;
    final watch = Stopwatch()..start();
    final limit = math.min(_remaining, budget);
    for (; checked < limit; checked++) {
      // Bound native sampling time as well as calls on slower devices.
      if (checked > 0 && watch.elapsedMicroseconds >= 4000) {
        break;
      }
      final value = havePiece(first + _cursor) ? 1 : 0;
      if (_pieces[_cursor] != value) {
        _pieces[_cursor] = value;
        changed = true;
      }
      _cursor = (_cursor + 1) % count;
    }
    _remaining -= checked;
    if (!changed) return;
    _merge(first, count, offset, length, pieceLength);
  }

  void _merge(int first, int count, int offset, int length, int pieceLength) {
    final next = <DownloadedRange>[];
    int? start;
    for (var n = 0; n <= count; n++) {
      if (n < count && _pieces[n] != 0) {
        start ??= math.max(0, (first + n) * pieceLength - offset);
      } else if (start != null) {
        next.add((
          start: start,
          end: math.min(length, (first + n) * pieceLength - offset),
        ));
        start = null;
      }
    }
    ranges = List.unmodifiable(next);
  }
}
