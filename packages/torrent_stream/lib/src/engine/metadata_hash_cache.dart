import 'dart:typed_data';

/// Reuses parsing of identical metadata, including concurrent requests.
/// Copies keys so callers cannot mutate cached data; storage is bounded.
class MetadataHashCache {
  MetadataHashCache(
    this.load, {
    this.maxEntries = 8,
    this.maxBytes = 1024 * 1024,
  });
  final Future<String> Function(Uint8List) load;
  final int maxEntries, maxBytes;
  final _entries = <(Uint8List, Future<String>)>[];
  int _bytes = 0;

  Future<String> hash(Uint8List bytes) {
    if (bytes.length > maxBytes || maxEntries < 1) return load(bytes);
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (!_equal(bytes, entry.$1)) continue;
      _entries.removeAt(i);
      _entries.add(entry);
      return entry.$2;
    }
    final copy = Uint8List.fromList(bytes);
    late final (Uint8List, Future<String>) entry;
    final result = Future<String>.sync(() => load(copy)).catchError((
      Object error,
      StackTrace stack,
    ) {
      if (_entries.remove(entry)) _bytes -= copy.length;
      Error.throwWithStackTrace(error, stack);
    });
    entry = (copy, result);
    _entries.add(entry);
    _bytes += copy.length;
    while (_entries.length > maxEntries || _bytes > maxBytes) {
      _bytes -= _entries.removeAt(0).$1.length;
    }
    return result;
  }

  bool _equal(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
