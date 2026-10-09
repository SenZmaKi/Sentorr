import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:libtorrent_dart/libtorrent_dart.dart';

import 'byte_source.dart';
import 'cancellation.dart';
import 'piece_scheduler.dart';

/// One file's bytes for one stream, read through [scheduler], which other
/// streams of the same torrent share.
class TorrentBytes implements ByteSource {
  TorrentBytes(
    this.handle,
    this.file,
    this.readPiece,
    this.scheduler, {
    int readAheadBytes = 16 * 1024 * 1024,
    this.maxCacheBytes = 24 * 1024 * 1024,
  }) : lookahead = max(1, (readAheadBytes / handle.pieceLength).ceil() - 1),
       pieceLength = handle.pieceLength;
  final TorrentHandle handle;
  final TorrentFileEntry file;
  final Future<Uint8List> Function(int, Cancellation) readPiece;
  final PieceScheduler scheduler;
  final int pieceLength, lookahead;
  final _prefetch = Cancellation();

  void prefetch(int start, int end) {
    final first = (file.offset + start) ~/ pieceLength;
    final last = (file.offset + end - 1) ~/ pieceLength;
    scheduler.demand(_prefetch, first, last, last - first, urgent: false);
  }

  final _cache = <int, Uint8List>{};
  final _loading = <int, (Cancellation, Future<Uint8List>)>{};
  int _cachedBytes = 0;
  final int maxCacheBytes;
  int get cachedBytes => _cachedBytes;
  @override
  String get name => file.path;
  @override
  int get length => file.size;
  @override
  Future<Uint8List> read(int offset, int count, Cancellation cancellation) =>
      _read(offset, count, cancellation, ahead: lookahead, urgent: true);

  /// Sparse, non-urgent metadata read without expanding the playback window.
  Future<Uint8List> readIndex(
    int offset,
    int count,
    Cancellation cancellation,
  ) => _read(offset, count, cancellation, ahead: 0, urgent: false);

  Future<Uint8List> _read(
    int offset,
    int count,
    Cancellation cancellation, {
    required int ahead,
    required bool urgent,
  }) async {
    if (offset < 0 || count < 0 || offset + count > length) {
      throw RangeError('Read outside selected file');
    }
    cancellation.check();
    Uint8List? output;
    for (var copied = 0; copied < count;) {
      cancellation.check();
      final absolute = file.offset + offset + copied;
      final piece = absolute ~/ pieceLength;
      scheduler.demand(
        cancellation,
        piece,
        (file.offset + length - 1) ~/ pieceLength,
        ahead,
        urgent: urgent,
      );
      final data = await cancellation.wait(_piece(piece));
      cancellation.check();
      final within = absolute % pieceLength;
      final take = min(count - copied, data.length - within);
      if (take <= 0) throw StateError('Invalid native piece layout');
      if (copied == 0 && take == count) {
        // Socket writes can borrow a piece; eviction only drops our reference.
        // Keep callers from modifying the cached bytes through this view.
        return Uint8List.sublistView(
          data,
          within,
          within + take,
        ).asUnmodifiableView();
      }
      output ??= Uint8List(count);
      output.setRange(copied, copied + take, data, within);
      copied += take;
    }
    return output ?? Uint8List(0);
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
    _prefetch.cancel();
    scheduler.release(_prefetch);
    for (final loading in _loading.values) {
      loading.$1.cancel();
    }
    _loading.clear();
    _cache.clear();
    _cachedBytes = 0;
    scheduler.prune();
  }
}
