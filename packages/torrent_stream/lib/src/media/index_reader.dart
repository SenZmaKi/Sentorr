import 'dart:math' as math;
import 'dart:typed_data';

/// Limited sparse reads. Container headers can skip media payload without
/// requesting or scanning it. Oversized or malformed indexes remain unknown.
class IndexReader {
  IndexReader(this.length, this.fetch);
  final int length;
  final Future<Uint8List> Function(int, int) fetch;
  static const maxBytes = 16 * 1024 * 1024;
  int _read = 0;

  Future<Uint8List> read(int offset, int count) async {
    if (offset < 0 ||
        count < 0 ||
        offset + count > length ||
        _read + count > maxBytes) {
      throw const FormatException('Index read limit');
    }
    _read += count;
    return fetch(offset, count);
  }

  Future<Uint8List> header(int offset) =>
      read(offset, math.min(16, length - offset));
}
