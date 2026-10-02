import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';

import 'byte_source.dart';
import 'cancellation.dart';
import 'piece_scheduler.dart';

class TorrentBytes implements ByteSource {
  TorrentBytes(
    this.handle,
    this.file,
    this.readPiece, {
    int readAheadBytes = 16 * 1024 * 1024,
  }) : scheduler = PieceScheduler(
         handle,
         lookahead: max(1, (readAheadBytes / handle.pieceLength).ceil() - 1),
       ),
       pieceLength = handle.pieceLength;
  final TorrentHandle handle;
  final TorrentFileEntry file;
  final Future<Uint8List> Function(int, Cancellation) readPiece;
  final PieceScheduler scheduler;
  final int pieceLength;
  final _cache = <int, Uint8List>{};
  final _loading = <int, (Cancellation, Future<Uint8List>)>{};
  int _cachedBytes = 0;
  static const maxCacheBytes = 24 * 1024 * 1024;
  int get cachedBytes => _cachedBytes;
  @override
  String get name => file.path;
  @override
  int get length => file.size;
  @override
  Future<Uint8List> read(
    int offset,
    int count,
    Cancellation cancellation,
  ) async {
    if (offset < 0 || count < 0 || offset + count > length) {
      throw RangeError('Read outside selected file');
    }
    cancellation.check();
    final output = Uint8List(count);
    for (var copied = 0; copied < count;) {
      cancellation.check();
      final absolute = file.offset + offset + copied;
      final piece = absolute ~/ pieceLength;
      scheduler.demand(
        cancellation,
        piece,
        (file.offset + length - 1) ~/ pieceLength,
      );
      final data = await cancellation.wait(_piece(piece));
      cancellation.check();
      final within = absolute % pieceLength;
      final take = min(count - copied, data.length - within);
      if (take <= 0) throw StateError('Invalid native piece layout');
      output.setRange(copied, copied + take, data, within);
      copied += take;
    }
    return output;
  }

  Future<Uint8List> _piece(int piece) async {
    final cached = _cache.remove(piece);
    if (cached != null) {
      _cache[piece] = cached;
      return cached;
    }
    if (_loading.containsKey(piece)) return _loading[piece]!.$2;
    final cancellation = Cancellation();
    final future = _load(piece, cancellation);
    _loading[piece] = (cancellation, future);
    try {
      return await future;
    } finally {
      if (_loading[piece]?.$2 == future) _loading.remove(piece);
    }
  }

  Future<Uint8List> _load(int piece, Cancellation cancellation) async {
    final data = await readPiece(piece, cancellation);
    cancellation.check();
    if (data.length != handle.pieceSize(piece)) {
      throw StateError('Unexpected native piece size');
    }
    if (data.length <= maxCacheBytes) {
      while (_cachedBytes + data.length > maxCacheBytes && _cache.isNotEmpty) {
        _cachedBytes -= _cache.remove(_cache.keys.first)!.length;
      }
      _cache[piece] = data;
      _cachedBytes += data.length;
    }
    return data;
  }

  @override
  void release(Cancellation cancellation) {
    scheduler.release(cancellation);
    for (final piece in _loading.keys.toList()) {
      if (!scheduler.needs(piece)) _loading.remove(piece)!.$1.cancel();
    }
  }

  void close() {
    scheduler.clear();
    for (final loading in _loading.values) {
      loading.$1.cancel();
    }
    _loading.clear();
    _cache.clear();
    _cachedBytes = 0;
  }
}
