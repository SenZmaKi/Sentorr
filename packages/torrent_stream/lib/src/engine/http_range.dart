class ByteRange {
  const ByteRange(this.start, this.end);
  final int start;
  final int end;
  int get length => end - start + 1;

  /// Null means ignore a malformed/unsupported Range and serve the full file.
  /// An unsatisfiable valid range throws, producing HTTP 416.
  static ByteRange? parse(String? header, int size) {
    if (header == null ||
        !header.startsWith('bytes=') ||
        header.contains(',')) {
      return null;
    }
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header);
    if (match == null) return null;
    final first = match[1]!;
    final last = match[2]!;
    if (first.isEmpty && last.isEmpty) return null;
    final a = first.isEmpty ? null : int.tryParse(first);
    final b = last.isEmpty ? null : int.tryParse(last);
    if ((first.isNotEmpty && a == null) || (last.isNotEmpty && b == null)) {
      return null;
    }
    if (a == null) {
      if (b == 0 || size == 0) throw const UnsatisfiableRange();
      return ByteRange((size - b!).clamp(0, size), size - 1);
    }
    if (b != null && b < a) return null;
    if (a >= size) throw const UnsatisfiableRange();
    return ByteRange(a, b == null ? size - 1 : b.clamp(a, size - 1));
  }
}

class UnsatisfiableRange implements Exception {
  const UnsatisfiableRange();
}
